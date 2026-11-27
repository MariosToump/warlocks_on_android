class_name BoomerangSpell
extends Spell
## Bought in the shop (v0.12): a spinning blade that flies out 420 px and
## comes back, hitting each wizard on its path up to twice.
## See docs/superpowers/specs/2026-11-27-remaining-spells-design.md.

const SCENE := preload("res://scenes/projectile_boomerang.tscn")
const FRAMES := preload("res://assets/sprites/effects/boomerang_frames.tres")

@export var damage_by_level: Array[float] = [6.0, 6.5, 7.0, 8.0]
@export var knockback_by_level: Array[float] = [360.0, 390.0, 420.0, 450.0]
@export var speed := 520.0
@export var out_range := 420.0


func _init() -> void:
	spell_name = "Boomerang"
	spell_id = "boomerang"
	icon = FRAMES.get_frame_texture("default", 1)
	cooldown_by_level = [5.0, 4.5, 4.0, 3.5]
	cast_time = 0.3
	release_time = 0.15


func reach() -> float:
	return out_range


func release(target: Vector2) -> void:
	var dir := (target - caster.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var b: Boomerang = SCENE.instantiate()
	b.caster = caster
	b.direction = dir
	b.speed = speed
	b.out_range = out_range
	b.max_range = INF # it turns back on its own
	b.damage = damage_by_level[level]
	b.knockback = knockback_by_level[level]
	b.position = caster.global_position + dir * 14.0
	caster.get_parent().add_child(b)
	Sfx.play_at("boomerang", caster.global_position)
