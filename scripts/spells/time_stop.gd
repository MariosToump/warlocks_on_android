class_name TimeStopSpell
extends Spell
## Bought in the shop (v0.12; reworked 2026-11-28): a 120 px circle up to
## 450 px away that freezes every enemy wizard inside it (see TimeStopField).
## Hits on them push 20% harder, and that lasts 2.5 s after they get out. Set
## up a Meteor, a Lightning into the lava, a Fireball they can't dodge.

const FRAMES := preload("res://assets/sprites/effects/time_stop_frames.tres")

## Was 2.0-2.6 s for spells; a frozen wizard is far stronger, so shorter.
@export var duration_by_level: Array[float] = [1.5, 1.7, 1.9, 2.1]
@export var max_range := 450.0


func _init() -> void:
	spell_name = "Time Stop"
	spell_id = "timestop"
	placed = true
	area_radius = 120.0
	icon = FRAMES.get_frame_texture("default", 0)
	cooldown_by_level = [9.0, 8.5, 8.0, 7.5] # was 12-10.5 (balance 2026-11-27)
	cast_time = 0.2
	release_time = 0.1


func reach() -> float:
	return max_range


func release(target: Vector2) -> void:
	var from := caster.global_position
	TimeStopField.spawn(from + (target - from).limit_length(max_range), caster, duration_by_level[level])
