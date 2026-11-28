class_name MeteorSpell
extends Spell
## Bought in the shop (v0.12): call a meteor on a spot up to 600 px away. A
## warning ring shows for 1 s, then a 75 px blast with a huge push and a
## crater (see MeteorStrike). Placed, so a touch drag aims the distance.

const FRAMES := preload("res://assets/sprites/effects/meteor_rock_frames.tres")

## 2026-11-28 (user: "it should feel like a meteor"): was 14-18 damage and
## 740-890 push (650-800 before 2026-11-27). The blast radius stays 85.
@export var damage_by_level: Array[float] = [20.0, 22.0, 24.0, 26.0]
@export var knockback_by_level: Array[float] = [980.0, 1040.0, 1100.0, 1160.0]
@export var max_range := 600.0


func _init() -> void:
	spell_name = "Meteor"
	spell_id = "meteor"
	placed = true
	area_radius = 85.0 # was 75 (balance 2026-11-27)
	icon = FRAMES.get_frame_texture("default", 0)
	cooldown_by_level = [8.0, 7.5, 7.0, 6.5]
	cast_time = 0.4
	release_time = 0.25


func reach() -> float:
	return max_range


func release(target: Vector2) -> void:
	var from := caster.global_position
	var at := from + (target - from).limit_length(max_range)
	var m := MeteorStrike.spawn(at, caster, damage_by_level[level], knockback_by_level[level])
	m.radius = area_radius
	m.delay = 0.85 # was 1.0 (balance 2026-11-27): less time to walk out
