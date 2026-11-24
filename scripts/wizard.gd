class_name Wizard
extends CharacterBody2D
## A wizard: movement, knockback physics, health, lava burning and animation.
## It doesn't read input itself. A controller (player or AI) sets either
## `move_target` (walk to a point) or `move_dir` (walk in a direction).

signal health_changed(current: float, maximum: float)
signal died(wizard: Wizard)

const DIRS := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
const MIRROR := {"west": "east", "south-west": "south-east", "north-west": "north-east"}

@export var max_health := 100.0
@export var move_speed := 140.0
@export var lava_dps := 8.0
## Exponential damping of knockback velocity (higher = stops sooner).
@export var knockback_friction := 3.0
## Each point of damage taken adds this much to knockback received
## (0.01 -> at 50 damage taken you fly 1.5x as far).
@export var knockback_per_damage := 0.01
@export var sprite_frames: SpriteFrames

var health := max_health
var damage_taken := 0.0
var alive := true
var on_lava := false
var arena: Arena

## Set by a controller. move_target wins if both are set.
var move_target = null # Vector2 or null
var move_dir := Vector2.ZERO

var knockback := Vector2.ZERO
var facing := "south"
var _sprite_base_y := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var smoke: CPUParticles2D = $Smoke
@onready var glow: PointLight2D = $Glow


func _ready() -> void:
	if sprite_frames:
		sprite.sprite_frames = sprite_frames
	_sprite_base_y = sprite.offset.y
	health = max_health
	_play("idle")


func _physics_process(delta: float) -> void:
	if not alive:
		return
	var walk := _walk_velocity()
	knockback *= exp(-knockback_friction * delta)
	if knockback.length() < 2.0:
		knockback = Vector2.ZERO
	velocity = walk + knockback
	move_and_slide()
	_clamp_to_arena()
	_update_lava(delta)
	_update_animation(walk)


func _walk_velocity() -> Vector2:
	if move_target != null:
		var to: Vector2 = move_target - global_position
		if to.length() <= move_speed * get_physics_process_delta_time():
			move_target = null
			return Vector2.ZERO
		return to.normalized() * move_speed
	if move_dir != Vector2.ZERO:
		return move_dir.limit_length(1.0) * move_speed
	return Vector2.ZERO


# --- health & knockback -----------------------------------------------------

func take_damage(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	damage_taken += amount
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()


## Push the wizard. Scaled up by how much damage it has taken.
func apply_knockback(impulse: Vector2) -> void:
	if alive:
		knockback += impulse * (1.0 + damage_taken * knockback_per_damage)


func reset(at: Vector2) -> void:
	global_position = at
	health = max_health
	damage_taken = 0.0
	knockback = Vector2.ZERO
	move_target = null
	move_dir = Vector2.ZERO
	alive = true
	visible = true
	modulate = Color.WHITE
	scale = Vector2.ONE
	health_changed.emit(health, max_health)
	_play("idle")


func _die() -> void:
	alive = false
	on_lava = false
	smoke.emitting = false
	glow.enabled = false
	velocity = Vector2.ZERO
	var t := create_tween().set_parallel()
	t.tween_property(self, "modulate", Color(1, 0.4, 0.1, 0), 0.8)
	t.tween_property(self, "scale", Vector2(0.4, 0.4), 0.8)
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
		take_damage(lava_dps * delta)


func _clamp_to_arena() -> void:
	if arena:
		var b := arena.get_bounds().grow(-8.0)
		global_position = global_position.clamp(b.position, b.end)


# --- animation --------------------------------------------------------------

func _update_animation(walk: Vector2) -> void:
	if walk.length() > 1.0:
		facing = dir_name(walk)
		_play("walk")
	else:
		_play("idle")


## Face a point without moving (used when casting).
func face(point: Vector2) -> void:
	facing = dir_name(point - global_position)


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
		anim = "idle_%s" % dir
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)
	# Idle is a single still frame: give it a 1px "breathing" bob.
	sprite.offset.y = _sprite_base_y - (1.0 if kind == "idle" and int(Time.get_ticks_msec() / 600.0) % 2 == 1 else 0.0)
