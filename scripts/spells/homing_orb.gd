class_name HomingOrbSpell
extends Spell
## D (bought in the shop): a slow purple orb that curves toward the nearest
## enemy. Easy to land on someone who isn't watching, easy to sidestep or
## reflect if they are. Its own round violet art (visual review 2026-11-27:
## it used to be a tinted fireball and was easy to mistake for one).

const PROJECTILE := preload("res://scenes/projectile_homing.tscn")
const FRAMES := preload("res://assets/sprites/effects/homing_orb_frames.tres")
const TINT := Color.WHITE

@export var damage_by_level: Array[float] = [7.0, 8.5, 10.0, 11.5] ## was 8-14 (balance 2026-11-27)
@export var knockback_by_level: Array[float] = [410.0, 440.0, 470.0, 500.0] ## was 480-570 (balance 2026-11-27)
@export var speed := 300.0
@export var max_range := 1100.0
@export var turn_rate := 1.9 ## radians per second (was 2.5: too hard to sidestep)


func _init() -> void:
	spell_name = "Homing Orb"
	spell_id = "homing"
	icon = FRAMES.get_frame_texture("default", 0)
	icon_tint = TINT
	cooldown_by_level = [7.5, 7.0, 6.5, 6.0] # was 6-4.5 (balance 2026-11-27)
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
	p.hit_kind = "homing"
	p.draws_shadow = true
	caster.get_parent().add_child(p)
	Sfx.attach_loop(p, "homing_hum")
	Sfx.play_at("homing", caster.global_position)
