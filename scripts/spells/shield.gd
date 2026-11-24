class_name ShieldSpell
extends Spell
## R: a bubble for a short time that reflects projectiles back (they then
## belong to the shielded wizard) and blocks lightning.

const BUBBLE := preload("res://assets/sprites/effects/shield_bubble_frames.tres")

@export var duration_by_level: Array[float] = [1.5, 1.75, 2.0, 2.25]


func _init() -> void:
	spell_name = "Shield"
	icon = BUBBLE.get_frame_texture("default", 0)
	cooldown_by_level = [10.0, 9.0, 8.0, 7.0]
	cast_time = 0.1
	release_time = 0.0


func release(_target: Vector2) -> void:
	caster.raise_shield(duration_by_level[level])
