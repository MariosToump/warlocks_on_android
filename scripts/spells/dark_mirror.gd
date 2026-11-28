class_name DarkMirrorSpell
extends Spell
## Bought in the shop (2026-11-28, replaces Rock Wall): raise dark glass panes
## round you, facing the aim, for a few seconds. A spell that flies into them
## goes straight back to its caster at the same speed (see DarkMirror). The
## user's rule: level 1 covers 1/3 of the ring, level 2 2/3, level 3 all of
## it. Bought = level 0 here, so: 0 -> 1/3, 1 -> 2/3, 2 and 3 -> the whole
## ring (3 also lasts longer).

const ICON := preload("res://assets/sprites/effects/dark_mirror_icon.png")
const ARCS := [TAU / 3.0, TAU * 2.0 / 3.0, TAU, TAU]

@export var duration_by_level: Array[float] = [2.5, 2.5, 2.5, 3.0]


func _init() -> void:
	spell_name = "Dark Mirror"
	spell_id = "mirror"
	icon = ICON
	cooldown_by_level = [9.0, 8.5, 8.0, 7.5]
	cast_time = 0.15
	release_time = 0.05


func arc() -> float:
	return ARCS[level]


func release(target: Vector2) -> void:
	DarkMirror.raise(caster, target, arc(), duration_by_level[level])
	Sfx.play_at("mirror", caster.global_position)
