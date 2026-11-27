class_name HomingOrbSpell
extends Spell
## D (bought in the shop): a slow purple orb that curves toward the nearest
## enemy. Easy to land on someone who isn't watching, easy to sidestep or
## reflect if they are. Reuses the fireball art, tinted.

const PROJECTILE := preload("res://scenes/projectile_fireball.tscn")
const FRAMES := preload("res://assets/sprites/effects/fireball_frames.tres")
const TINT := Color(0.75, 0.45, 1.6)

@export var damage_by_level: Array[float] = [8.0, 10.0, 12.0, 14.0]
@export var knockback_by_level: Array[float] = [480.0, 510.0, 540.0, 570.0]
@export var speed := 300.0
@export var max_range := 1100.0
@export var turn_rate := 2.5 ## radians per second


func _init() -> void:
	spell_name = "Homing Orb"
	spell_id = "homing"
	icon = FRAMES.get_frame_texture("default", 0)
	icon_tint = TINT
	cooldown_by_level = [6.0, 5.5, 5.0, 4.5]
	cast_time = 0.3
	release_time = 0.18


func reach() -> float:
	return 600.0 # it curves, so aim roughly; tap picks targets this close


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
	p.homing_turn = turn_rate
	p.position = caster.global_position + dir * 14.0
	p.modulate = TINT
	p.scale = Vector2(0.85, 0.85)
	caster.get_parent().add_child(p)
	Sfx.play_at("homing", caster.global_position)
