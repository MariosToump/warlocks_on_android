class_name FireballSpell
extends Spell
## Q: fast projectile, small damage, medium knockback.

const PROJECTILE := preload("res://scenes/projectile_fireball.tscn")
const FRAMES := preload("res://assets/sprites/effects/fireball_frames.tres")

@export var damage_by_level: Array[float] = [6.0, 8.0, 10.0, 12.0]
@export var knockback_by_level: Array[float] = [520.0, 560.0, 600.0, 640.0]
@export var speed := 560.0
@export var max_range := 850.0


func _init() -> void:
	spell_name = "Fireball"
	icon = FRAMES.get_frame_texture("default", 0)
	cooldown_by_level = [2.0, 1.8, 1.6, 1.4]
	cast_time = 0.3
	release_time = 0.18


func release(target: Vector2) -> void:
	var dir := (target - caster.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var p: Projectile = PROJECTILE.instantiate()
	p.caster = caster
	p.direction = dir
	p.speed = speed
	p.max_range = max_range
	p.damage = damage_by_level[level]
	p.knockback = knockback_by_level[level]
	p.leaves_crater = true
	# Start just outside the caster's body so it can't hit itself.
	p.position = caster.global_position + dir * 14.0
	caster.get_parent().add_child(p)
	Sfx.play_at("fireball", caster.global_position)
