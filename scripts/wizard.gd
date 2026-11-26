class_name Wizard
extends CharacterBody2D
## A wizard: movement, knockback physics, health, lava burning and animation.
## It doesn't read input itself. A controller (player or AI) sets either
## `move_target` (walk to a point) or `move_dir` (walk in a direction).

signal health_changed(current: float, maximum: float)
## Every bit of damage. `source` = the wizard who dealt it; null = lava.
signal damaged(amount: float, source: Wizard)
signal died(wizard: Wizard)
signal cast_started(slot: String)

enum TeamColor { RED, BLUE, GREEN, PURPLE }
## Hue rotation applied to the red robe for each team colour.
const TEAM_HUE := {TeamColor.RED: 0.0, TeamColor.BLUE: 0.62, TeamColor.GREEN: 0.33, TeamColor.PURPLE: 0.8}

const DIRS := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
const MIRROR := {"west": "east", "south-west": "south-east", "north-west": "north-east"}
## Animations made in fewer directions (hurt has no east; death is
## south/south-east/north only) fall back to the closest one that exists.
const DIR_FALLBACK := {"east": ["south-east"], "south-east": ["east", "south"], "north-east": ["east", "north"]}
const SHIELD_FRAMES := preload("res://assets/sprites/effects/shield_bubble_frames.tres")
## Radius of the shield bubble (projectiles bounce off here).
const SHIELD_RADIUS := 22.0

@export var max_health := 100.0
@export var move_speed := 165.0
@export var lava_dps := 20.0
## Exponential damping of knockback velocity (higher = stops sooner).
@export var knockback_friction := 3.0
## Each point of damage taken adds this much to knockback received
## (0.01 -> at 50 damage taken you fly 1.5x as far).
@export var knockback_per_damage := 0.015
@export var sprite_frames: SpriteFrames
@export var team_color := TeamColor.RED:
	set(v):
		team_color = v
		if is_node_ready():
			_apply_team_color()

var health := max_health
var damage_taken := 0.0
## Who hit us last, and when (seconds, Time.get_ticks_msec() based).
var last_attacker: Wizard = null
var last_hit_at := -100.0
var alive := true
var on_lava := false
var arena: Arena
## Item effects (set by Shop.apply_items; they survive round resets and are
## cleared at a new match). Focus Gem: spells multiply their cooldown by this.
var cooldown_multiplier := 1.0
var speed_multiplier := 1.0 ## Boots
var knockback_taken_multiplier := 1.0 ## Stone Cloak
var lava_multiplier := 1.0 ## Fire Ring
## Item ids bought in the shop (max Shop.MAX_ITEMS).
var items: Array[String] = []
## Round wins this match (set by the game): bots gang up on the leader.
var match_wins := 0

## Set by a controller. move_target wins if both are set.
var move_target = null # Vector2 or null
var move_dir := Vector2.ZERO
## Auto-attack: walk up to this wizard and keep hitting it with the staff
## (slot "A"). Cleared when it dies; controllers clear it when you move.
var attack_target: Wizard = null
## Stop auto-attacking after the next swing (a single tap of attack).
var attack_once := false

var knockback := Vector2.ZERO
var facing := "south"
## Seconds of shield left (Shield spell). Reflects projectiles, blocks lightning.
var shield_left := 0.0
var _sprite_base_y := 0.0

# Casting: the wizard stands still for the spell's cast_time and the
# spell fires at its release_time.
var _casting: Spell = null
var _cast_elapsed := 0.0
var _cast_target := Vector2.ZERO
var _cast_released := false

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var smoke: CPUParticles2D = $Smoke
@onready var glow: PointLight2D = $Glow
@onready var spells: Node = $Spells
@onready var bubble: AnimatedSprite2D = $Bubble


func _ready() -> void:
	add_to_group("wizards")
	bubble.sprite_frames = SHIELD_FRAMES
	bubble.offset = -SHIELD_FRAMES.get_meta("pivot_px", Vector2.ZERO)
	bubble.visible = false
	if sprite_frames:
		sprite.sprite_frames = sprite_frames
	_sprite_base_y = sprite.offset.y
	health = max_health
	_apply_team_color()
	_play("idle")


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_update_auto_attack()
	_update_cast(delta)
	_update_shield(delta)
	# Attacks can be cut short by walking once the hit has landed.
	if _casting and _casting.cancel_on_move and _cast_released and _wants_to_walk():
		_casting = null
	var walk := Vector2.ZERO if _casting else _walk_velocity()
	knockback *= exp(-knockback_friction * delta)
	if knockback.length() < 2.0:
		knockback = Vector2.ZERO
	velocity = walk + knockback
	move_and_slide()
	_clamp_to_arena()
	_update_lava(delta)
	_update_animation(walk)


func _wants_to_walk() -> bool:
	return move_target != null or move_dir != Vector2.ZERO


func _walk_velocity() -> Vector2:
	var speed := move_speed * speed_multiplier
	if move_target != null:
		var to: Vector2 = move_target - global_position
		if to.length() <= speed * get_physics_process_delta_time():
			move_target = null
			return Vector2.ZERO
		return to.normalized() * speed
	if move_dir != Vector2.ZERO:
		return move_dir.limit_length(1.0) * speed
	return Vector2.ZERO


# --- spells -------------------------------------------------------------------

func get_spell(slot: String) -> Spell:
	return spells.get_node_or_null(slot) as Spell


## Start casting the spell in `slot` toward a world point. Returns false if
## it can't be cast right now (dead, already casting, on cooldown, empty).
func cast(slot: String, target: Vector2) -> bool:
	var spell := get_spell(slot)
	if not alive or _casting or spell == null or not spell.is_ready():
		return false
	_casting = spell
	_cast_elapsed = 0.0
	_cast_target = target
	_cast_released = false
	spell.start_cooldown()
	face(target)
	_play_cast_anim()
	cast_started.emit(slot)
	return true


## Start auto-attacking `target` (null stops). `once` = a single swing.
func attack(target: Wizard, once := false) -> void:
	attack_target = target
	attack_once = once


## Distance (centre to centre) at which the staff swing is started.
func attack_range() -> float:
	var staff := get_spell("A")
	return staff.attack_range if staff is StaffStrikeSpell else 0.0


func _update_auto_attack() -> void:
	if attack_target == null:
		return
	if not is_instance_valid(attack_target) or not attack_target.alive or get_spell("A") == null:
		attack_target = null
		return
	var to := attack_target.global_position - global_position
	if to.length() <= attack_range():
		move_target = null # in reach: stand and swing
		if cast("A", attack_target.global_position) and attack_once:
			attack_target = null
	elif not _casting:
		move_target = attack_target.global_position # chase


func is_casting() -> bool:
	return _casting != null


func _update_cast(delta: float) -> void:
	if not _casting:
		return
	_cast_elapsed += delta
	if not _cast_released and _cast_elapsed >= _casting.release_time:
		_cast_released = true
		_casting.release(_cast_target)
	if _cast_elapsed >= _casting.cast_time:
		_casting = null


func _cancel_cast() -> void:
	_casting = null


# --- shield -------------------------------------------------------------------

func raise_shield(duration: float) -> void:
	shield_left = duration
	bubble.visible = true
	bubble.modulate.a = 1.0
	bubble.play("default")


## Bubble lights up when something bounces off it.
func bubble_flash() -> void:
	bubble.self_modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(bubble, "self_modulate", Color.WHITE, 0.2)


func is_shielded() -> bool:
	return alive and shield_left > 0.0


func _update_shield(delta: float) -> void:
	if shield_left <= 0.0:
		return
	shield_left = maxf(shield_left - delta, 0.0)
	# Flicker during the last 0.4 s as a warning.
	bubble.modulate.a = 1.0 if shield_left > 0.4 or int(shield_left * 20.0) % 2 == 0 else 0.3
	if shield_left <= 0.0:
		bubble.visible = false
		bubble.stop()


# --- health & knockback -----------------------------------------------------

## `source` = the wizard who dealt it (null for lava etc.).
func take_damage(amount: float, source: Wizard = null) -> void:
	if not alive or amount <= 0.0:
		return
	if source != null and source != self:
		last_attacker = source
		last_hit_at = Time.get_ticks_msec() / 1000.0
	health = maxf(health - amount, 0.0)
	damage_taken += amount
	damaged.emit(amount, source)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()


## Hit reaction: a brief white flash and the hurt animation, turned to
## face where the hit came from. `from_dir` is the direction the hit was
## travelling (zero = keep facing).
func flash_hit(from_dir := Vector2.ZERO) -> void:
	sprite.self_modulate = Color(4, 4, 4)
	var t := create_tween()
	t.tween_property(sprite, "self_modulate", Color.WHITE, 0.15)
	if alive and not _casting:
		if from_dir != Vector2.ZERO:
			facing = dir_name(-from_dir)
		_play("hurt")
		sprite.frame = 0
		sprite.play()


## Push the wizard. Scaled up by how much damage it has taken.
func apply_knockback(impulse: Vector2) -> void:
	if alive:
		knockback += impulse * (1.0 + damage_taken * knockback_per_damage) * knockback_taken_multiplier


func reset(at: Vector2) -> void:
	global_position = at
	health = max_health
	damage_taken = 0.0
	last_attacker = null
	knockback = Vector2.ZERO
	move_target = null
	move_dir = Vector2.ZERO
	attack_target = null
	alive = true
	_casting = null
	shield_left = 0.0
	bubble.visible = false
	sprite.self_modulate = Color.WHITE
	sprite.modulate = Color.WHITE
	visible = true
	modulate = Color.WHITE
	scale = Vector2.ONE
	health_changed.emit(health, max_health)
	_play("idle")
	reset_physics_interpolation() # a jump, not a slide


func _die() -> void:
	alive = false
	attack_target = null
	_cancel_cast()
	on_lava = false
	smoke.emitting = false
	glow.enabled = false
	velocity = Vector2.ZERO
	shield_left = 0.0
	bubble.visible = false
	# Collapse (death animation), then burn away.
	_play("death")
	sprite.frame = 0
	sprite.play()
	var t := create_tween()
	t.tween_interval(0.6)
	t.set_parallel()
	t.tween_property(self, "modulate", Color(1, 0.4, 0.1, 0), 0.8)
	t.tween_property(self, "scale", Vector2(0.6, 0.6), 0.8)
	t.chain().tween_callback(func(): visible = false)
	died.emit(self)


# --- lava -------------------------------------------------------------------

func _update_lava(delta: float) -> void:
	var now := arena != null and arena.is_lava_at(global_position)
	if now != on_lava:
		on_lava = now
		smoke.emitting = now
		glow.enabled = now
		if not now:
			sprite.modulate = Color.WHITE
	if on_lava:
		# Pulse the sprite hot orange while burning.
		var p := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
		sprite.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.6, 0.75, 0.35), 0.4 + 0.4 * p)
		take_damage(lava_dps * lava_multiplier * delta)


func _clamp_to_arena() -> void:
	if arena:
		var b := arena.get_bounds().grow(-8.0)
		global_position = global_position.clamp(b.position, b.end)


# --- animation --------------------------------------------------------------

func _update_animation(walk: Vector2) -> void:
	if _casting:
		return # cast animation keeps playing
	if sprite.animation.begins_with("hurt") and sprite.is_playing() and knockback.length() > 60.0:
		return # still flying from the hit
	if walk.length() > 1.0:
		facing = dir_name(walk)
		_play("walk")
	elif sprite.animation.begins_with("cast") and sprite.is_playing():
		return # let the cast follow-through finish when standing still
	elif sprite.animation.begins_with("hurt") and sprite.is_playing():
		return # finish the flinch
	else:
		_play("idle")


## Face a point without moving (used when casting).
func face(point: Vector2) -> void:
	facing = dir_name(point - global_position)


## Plays cast_<dir>, sped up so it fits the spell's cast time (a bit of
## follow-through past it is fine: walking takes over after).
func _play_cast_anim() -> void:
	var kind := _casting.anim
	_play(kind)
	var frames := sprite.sprite_frames
	if frames and sprite.animation.begins_with(kind):
		var length := frames.get_frame_count(sprite.animation) / frames.get_animation_speed(sprite.animation)
		if _casting.anim_fits_cast:
			sprite.speed_scale = length / _casting.cast_time
		else:
			sprite.speed_scale = maxf(1.0, length / (_casting.cast_time * 1.6))
		sprite.frame = 0
		sprite.play()


func _apply_team_color() -> void:
	var mat := sprite.material as ShaderMaterial
	if mat:
		mat = mat.duplicate() # each wizard its own colour
		mat.set_shader_parameter("hue_shift", TEAM_HUE[team_color])
		sprite.material = mat


static func dir_name(v: Vector2) -> String:
	var i := wrapi(roundi(v.angle() / (PI / 4.0)), 0, 8)
	return DIRS[i]


func _play(kind: String) -> void:
	if sprite.sprite_frames == null:
		return
	# West-facing sprites are the east ones flipped.
	var dir: String = MIRROR.get(facing, facing)
	sprite.flip_h = MIRROR.has(facing)
	var anim := "%s_%s" % [kind, dir]
	if not sprite.sprite_frames.has_animation(anim):
		for alt in DIR_FALLBACK.get(dir, []):
			if sprite.sprite_frames.has_animation("%s_%s" % [kind, alt]):
				anim = "%s_%s" % [kind, alt]
				break
	if not sprite.sprite_frames.has_animation(anim):
		anim = "idle_%s" % dir
	var timed := kind == "cast" or kind == "attack" # speed set by _play_cast_anim
	if not timed:
		sprite.speed_scale = 1.0
	if sprite.animation != anim or (not timed and not sprite.is_playing()):
		sprite.play(anim)
	# Idle is a single still frame: give it a 1px "breathing" bob.
	sprite.offset.y = _sprite_base_y - (1.0 if kind == "idle" and int(Time.get_ticks_msec() / 600.0) % 2 == 1 else 0.0)
