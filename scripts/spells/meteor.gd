class_name MeteorSpell
extends Spell
## Bought in the shop (v0.12): call a meteor on a spot up to 600 px away. A
## warning ring shows for 1 s, then a 75 px blast with a huge push and a
## crater (see MeteorStrike). Placed, so a touch drag aims the distance.

const FRAMES := preload("res://assets/sprites/effects/meteor_rock_frames.tres")

@export var damage_by_level: Array[float] = [14.0, 15.0, 16.0, 18.0]
@export var knockback_by_level: Array[float] = [650.0, 700.0, 750.0, 800.0]
@export var max_range := 600.0


func _init() -> void:
	spell_name = "Meteor"
	spell_id = "meteor"
	placed = true
	area_radius = 75.0
	icon = FRAMES.get_frame_texture("default", 0)
	cooldown_by_level = [8.0, 7.5, 7.0, 6.5]
	cast_time = 0.4
	release_time = 0.25


func reach() -> float:
	return max_range


func release(target: Vector2) -> void:
	var from := caster.global_position
	var at := from + (target - from).limit_length(max_range)
	MeteorStrike.spawn(at, caster, damage_by_level[level], knockback_by_level[level])
