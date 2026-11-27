class_name Projectile
extends Area2D
## A flying spell. Position is on the ground (so y-sorting and hits use
## feet); the sprite is drawn at hand height. Hits the first wizard that
## isn't its caster: damage + knockback along its flight direction.

const IMPACT := preload("res://scenes/effect_one_shot.tscn")

@export var impact_frames: SpriteFrames
@export var impact_scale := 1.0

var caster: Wizard
var direction := Vector2.RIGHT
var speed := 560.0
var max_range := 650.0
var damage := 6.0
var knockback := 380.0
## Homing (Homing Orb): turn toward the nearest living enemy of the current
## caster within `homing_radius`, at up to this many radians per second.
## 0 = flies straight. After a shield reflection it hunts the new owner's enemies.
var homing_turn := 0.0
var homing_radius := 520.0
## Swap orb: called as on_hit.call(projectile, wizard) instead of damage +
## knockback when it hits an unshielded wizard.
var on_hit: Callable
## Fireballs scorch a crater (slows walkers) where they burst.
var leaves_crater := false

## Seconds since spawned (bots only notice projectiles after their reaction delay).
var age := 0.0
## Set by the first shield reflection: from then on it flies at twice the
## speed and range (only once, so two shields can't ping-pong it faster).
var reflected := false
var _travelled := 0.0
var _done := false

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	add_to_group("projectiles")
	rotation = 0.0
	sprite.rotation = direction.angle()
	sprite.play()
	body_entered.connect(_on_body_entered)
	reset_physics_interpolation() # don't slide in from the origin


func _physics_process(delta: float) -> void:
	if _done or _frozen():
		return
	age += delta
	if homing_turn > 0.0:
		_steer(delta)
	var step := direction * speed * delta
	position += step
	_travelled += step.length()
	_check_shields()
	if _travelled >= max_range:
		_explode(0.6)


## Inside a Time Stop: stand still and stop animating.
func _frozen() -> bool:
	var f := TimeStopField.freezes(get_tree(), global_position)
	sprite.speed_scale = 0.0 if f else 1.0
	return f


func _steer(delta: float) -> void:
	var prey := homing_target()
	if prey == null:
		return
	var want := global_position.direction_to(prey.global_position)
	var turn := clampf(direction.angle_to(want), -homing_turn * delta, homing_turn * delta)
	direction = direction.rotated(turn)
	sprite.rotation = direction.angle()


## The wizard a homing projectile is chasing (nearest living enemy in range).
func homing_target() -> Wizard:
	var best: Wizard = null
	var best_d := homing_radius
	for node in get_tree().get_nodes_in_group("wizards"):
		var w := node as Wizard
		if w == caster or not w.alive:
			continue
		var d := global_position.distance_to(w.global_position)
		if d < best_d:
			best = w
			best_d = d
	return best


## Bounce off any enemy shield bubble we're inside and moving into: the
## projectile turns around, now belongs to the shielded wizard, and (the
## first time) comes back at double speed and double range.
func _check_shields() -> void:
	for node in get_tree().get_nodes_in_group("wizards"):
		var w := node as Wizard
		if w == caster or not w.is_shielded():
			continue
		var out := global_position - w.global_position
		if out.length() > Wizard.SHIELD_RADIUS or direction.dot(out) >= 0.0:
			continue
		var n := out.normalized() if out != Vector2.ZERO else -direction
		direction = direction.bounce(n).normalized()
		if direction.dot(n) < 0.3: # glancing hits still head clearly away
			direction = (direction + n).normalized()
		global_position = w.global_position + n * (Wizard.SHIELD_RADIUS + 1.0)
		caster = w
		if not reflected:
			reflected = true
			speed *= 2.0
			max_range *= 2.0
		_travelled = 0.0
		age = 0.0 # a new threat: bots need their reaction time again
		sprite.rotation = direction.angle()
		w.bubble_flash()
		return


func _on_body_entered(body: Node) -> void:
	if _done:
		return
	if body is Prop:
		# Rocks stop spells; boulders get shoved.
		(body as Prop).push(direction * knockback, caster)
		_explode(impact_scale)
		return
	if body == caster or not (body is Wizard) or not body.alive:
		return
	var w := body as Wizard
	if w.is_shielded():
		return # _check_shields bounces it
	if on_hit.is_valid():
		on_hit.call(self, w)
		_explode(impact_scale)
		return
	w.take_damage(damage, caster)
	w.apply_knockback(direction * knockback)
	w.flash_hit(direction)
	_explode(impact_scale)


func _explode(fx_scale: float) -> void:
	_done = true
	if leaves_crater and caster and caster.arena and not caster.arena.is_lava_at(global_position):
		Crater.spawn(caster.arena, global_position)
	Sfx.play_at("hit", global_position, 0.0 if fx_scale == impact_scale else -8.0)
	if impact_frames:
		var fx: AnimatedSprite2D = IMPACT.instantiate()
		fx.sprite_frames = impact_frames
		fx.position = position + sprite.position
		fx.scale = Vector2(fx_scale, fx_scale)
		get_parent().add_child(fx)
	queue_free()
