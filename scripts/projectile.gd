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

var _travelled := 0.0
var _done := false

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	rotation = 0.0
	sprite.rotation = direction.angle()
	sprite.play()
	body_entered.connect(_on_body_entered)
	reset_physics_interpolation() # don't slide in from the origin


func _physics_process(delta: float) -> void:
	if _done:
		return
	var step := direction * speed * delta
	position += step
	_travelled += step.length()
	_check_shields()
	if _travelled >= max_range:
		_explode(0.6)


## Bounce off any enemy shield bubble we're inside and moving into: the
## projectile turns around and now belongs to the shielded wizard.
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
		_travelled = 0.0
		sprite.rotation = direction.angle()
		w.bubble_flash()
		return


func _on_body_entered(body: Node) -> void:
	if _done or body == caster or not (body is Wizard) or not body.alive:
		return
	var w := body as Wizard
	if w.is_shielded():
		return # _check_shields bounces it
	w.take_damage(damage)
	w.apply_knockback(direction * knockback)
	w.flash_hit(direction)
	_explode(impact_scale)


func _explode(fx_scale: float) -> void:
	_done = true
	if impact_frames:
		var fx: AnimatedSprite2D = IMPACT.instantiate()
		fx.sprite_frames = impact_frames
		fx.position = position + sprite.position
		fx.scale = Vector2(fx_scale, fx_scale)
		get_parent().add_child(fx)
	queue_free()
