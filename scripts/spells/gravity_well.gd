class_name GravityWellSpell
extends Spell
## Bought in the shop (v0.12): open a vortex on a spot up to 500 px away that
## drags enemies within 160 px to its centre for 2.5 s (see GravityWell).
## Placed at the lava's edge, it pulls people in.

const FRAMES := preload("res://assets/sprites/effects/gravity_well_frames.tres")

@export var pull_by_level: Array[float] = [220.0, 245.0, 270.0, 300.0]
@export var max_range := 500.0


func _init() -> void:
	spell_name = "Gravity Well"
	spell_id = "well"
	placed = true
	area_radius = 160.0
	icon = FRAMES.get_frame_texture("default", 0)
	cooldown_by_level = [10.0, 9.5, 9.0, 8.5]
	cast_time = 0.35
	release_time = 0.2


func reach() -> float:
	return max_range


func release(target: Vector2) -> void:
	var from := caster.global_position
	GravityWell.spawn(from + (target - from).limit_length(max_range), caster, pull_by_level[level])
