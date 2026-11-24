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
var speed := 460.0
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


func _physics_process(delta: float) -> void:
	if _done:
		return
	var step := direction * speed * delta
	position += step
	_travelled += step.length()
	if _travelled >= max_range:
		_explode(0.6)


func _on_body_entered(body: Node) -> void:
	if _done or body == caster or not (body is Wizard) or not body.alive:
		return
	var w := body as Wizard
	w.take_damage(damage)
	w.apply_knockback(direction * knockback)
	w.flash_hit()
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
