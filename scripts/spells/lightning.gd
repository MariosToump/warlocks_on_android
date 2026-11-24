class_name LightningSpell
extends Spell
## E: an instant short bolt in a line. Hits the first wizard on the line
## for high knockback. A shield stops it.

const HIT := preload("res://assets/sprites/effects/lightning_hit_frames.tres")
const BOLT := preload("res://scripts/lightning_bolt.gd")

@export var damage_by_level: Array[float] = [8.0, 10.0, 12.0, 14.0]
@export var knockback_by_level: Array[float] = [560.0, 600.0, 640.0, 680.0]
@export var max_range := 230.0
## How far from the line a wizard's centre can be and still get hit.
@export var hit_width := 14.0


func _init() -> void:
	spell_name = "Lightning"
	icon = HIT.get_frame_texture("default", 4)
	cooldown_by_level = [5.0, 4.5, 4.0, 3.5]
	cast_time = 0.3
	release_time = 0.15


func release(target: Vector2) -> void:
	var from := caster.global_position
	var dir := (target - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var end := from + dir * max_range

	# First wizard along the line (or its shield bubble).
	var best: Wizard = null
	var best_t := INF
	for node in caster.get_tree().get_nodes_in_group("wizards"):
		var w := node as Wizard
		if w == caster or not w.alive:
			continue
		var reach := (Wizard.SHIELD_RADIUS if w.is_shielded() else hit_width)
		var t := (w.global_position - from).dot(dir)
		if t < 0.0 or t > max_range + reach:
			continue
		var off := (w.global_position - (from + dir * t)).length()
		if off <= reach and t < best_t:
			best = w
			best_t = t

	var parent := caster.get_parent()
	if best:
		if best.is_shielded():
			end = from + dir * maxf(best_t - Wizard.SHIELD_RADIUS, 0.0)
			EffectOneShot.spawn_at_feet(HIT, parent, end).scale = Vector2(0.6, 0.6)
		else:
			end = from + dir * best_t
			best.take_damage(damage_by_level[level])
			best.apply_knockback(dir * knockback_by_level[level])
			best.flash_hit(dir)
			EffectOneShot.spawn_at_feet(HIT, parent, best.global_position)

	var bolt: Node2D = BOLT.new()
	bolt.from = from + dir * 10.0
	bolt.to = end
	parent.add_child(bolt)
