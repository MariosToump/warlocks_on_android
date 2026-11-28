class_name LightningSpell
extends Spell
## E: an instant bolt in a line. Hits the first wizard on the line for high
## knockback. A shield stops it. The hitbox is a capsule around the drawn bolt;
## its last `tip_length` px are a wider "tip" that pushes harder (v0.11).

const HIT := preload("res://assets/sprites/effects/lightning_hit_frames.tres")
const BOLT := preload("res://scripts/lightning_bolt.gd")

@export var damage_by_level: Array[float] = [8.0, 10.0, 12.0, 14.0]
@export var knockback_by_level: Array[float] = [700.0, 740.0, 780.0, 820.0]
@export var max_range := 450.0
## How far from the line a wizard's centre can be and still get hit (covers
## the drawn bolt: +-6 px jitter and a 4 px line, plus the wizard's body).
@export var hit_width := 16.0
@export_group("Tip")
## The last stretch of the bolt: easier to land and pushes harder.
@export var tip_length := 70.0
@export var tip_width := 28.0
@export var tip_knockback := 1.25
@export_group("")


func _init() -> void:
	spell_name = "Lightning"
	icon = HIT.get_frame_texture("default", 4)
	cooldown_by_level = [5.0, 4.5, 4.0, 3.5]
	cast_time = 0.3
	release_time = 0.15


func release(target: Vector2) -> void:
	Sfx.play_at("lightning", caster.global_position)
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
		var t := (w.global_position - from).dot(dir)
		var mirrored := DarkMirror.covers(w, from - w.global_position)
		var hit_reach := DarkMirror.RADIUS if mirrored else Wizard.SHIELD_RADIUS if w.is_shielded() else width_at(t)
		if t < 0.0 or t > max_range + hit_reach:
			continue
		var off := (w.global_position - (from + dir * t)).length()
		if off <= hit_reach and t < best_t:
			best = w
			best_t = t

	# A rock in the way stops the bolt first (and shoves a boulder).
	var rock := Prop.first_on_ray(caster.get_tree(), from, dir, max_range, hit_width * 0.5)
	if not rock.is_empty() and (best == null or rock[1] < best_t):
		best = null
		end = from + dir * rock[1]
		(rock[0] as Prop).push(dir * knockback_by_level[level], caster)

	var parent := caster.get_parent()
	if best:
		if DarkMirror.covers(best, from - best.global_position):
			# Dark Mirror: the bolt stops on the glass and goes straight back
			# down its own line into the caster (unless they're shielded).
			end = from + dir * maxf(best_t - DarkMirror.RADIUS, 0.0)
			DarkMirror.of(best).flash()
			Sfx.play_at("mirror_reflect", end)
			if not caster.is_shielded():
				caster.take_damage(damage_by_level[level], best)
				caster.apply_knockback(-dir * knockback_by_level[level])
				caster.flash_hit(-dir, "lightning")
				EffectOneShot.spawn_at_feet(HIT, parent, caster.global_position)
			var back: Node2D = BOLT.new()
			back.from = end
			back.to = from + dir * 4.0
			parent.add_child(back)
		elif best.is_shielded():
			end = from + dir * maxf(best_t - Wizard.SHIELD_RADIUS, 0.0)
			EffectOneShot.spawn_at_feet(HIT, parent, end).scale = Vector2(0.6, 0.6)
		else:
			end = from + dir * best_t
			var tip := is_tip(best_t)
			best.take_damage(damage_by_level[level], caster)
			best.apply_knockback(dir * knockback_by_level[level] * (tip_knockback if tip else 1.0))
			best.flash_hit(dir, "lightning")
			var spark := EffectOneShot.spawn_at_feet(HIT, parent, best.global_position)
			if tip:
				spark.scale = Vector2(1.6, 1.6)

	var bolt: Node2D = BOLT.new()
	bolt.from = from + dir * 10.0
	bolt.to = end
	parent.add_child(bolt)


## Is a hit this far along the bolt a tip hit?
func is_tip(t: float) -> bool:
	return t >= max_range - tip_length


## Hit radius around the bolt this far along it.
func width_at(t: float) -> float:
	return tip_width if is_tip(t) else hit_width
