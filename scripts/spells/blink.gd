class_name BlinkSpell
extends Spell
## W: short teleport toward the mouse. Cancels knockback, so a well-timed
## blink saves you from flying into the lava.

const PUFF := preload("res://assets/sprites/effects/blink_puff_frames.tres")
const COLOR := Color(0.72, 0.5, 1.0)

@export var max_distance := 200.0


func _init() -> void:
	spell_name = "Blink"
	icon = PUFF.get_frame_texture("default", 5)
	cooldown_by_level = [6.0, 5.25, 4.5, 3.75]
	cast_time = 0.12
	release_time = 0.06


func release(target: Vector2) -> void:
	Sfx.play_at("blink", caster.global_position)
	var from := caster.global_position
	var to := from + (target - from).limit_length(max_distance)
	if caster.arena:
		var b := caster.arena.get_bounds().grow(-8.0)
		to = to.clamp(b.position, b.end)
	var fx_parent := caster.get_parent()
	EffectOneShot.spawn_at_feet(PUFF, fx_parent, from)
	caster.global_position = to
	caster.last_blink_at = GameClock.now()
	caster.knockback = Vector2.ZERO
	caster.move_target = null
	caster.reset_physics_interpolation()
	EffectOneShot.spawn_at_feet(PUFF, fx_parent, to).speed_scale = 1.4
	# Visual review 2026-11-27: the puff alone was a 3 px dot. A flash at
	# both ends and after-images along the path show where you went.
	FlashFx.afterimages(fx_parent, caster, from, to, COLOR)
	FlashFx.ring(fx_parent, from + Vector2(0, -12), COLOR, 16.0)
	FlashFx.ring(fx_parent, to + Vector2(0, -12), COLOR, 22.0, 0.28)
