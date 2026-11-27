class_name SwapSpell
extends Spell
## Bought in the shop (v0.12): a fast orb; on a hit you and the target trade
## places (no damage) and both stop flying. A shield reflects it (then it
## swaps the shielder with whoever it hits next).

const SCENE := preload("res://scenes/projectile_swap.tscn")
const FRAMES := preload("res://assets/sprites/effects/swap_orb_frames.tres")
const PUFF := preload("res://assets/sprites/effects/swap_puff_frames.tres")

@export var range_by_level: Array[float] = [650.0, 700.0, 750.0, 800.0]
@export var speed := 650.0


func _init() -> void:
	spell_name = "Swap"
	spell_id = "swap"
	icon = FRAMES.get_frame_texture("default", 0)
	cooldown_by_level = [9.0, 8.5, 8.0, 7.5]
	cast_time = 0.25
	release_time = 0.12


func reach() -> float:
	return range_by_level[level]


func release(target: Vector2) -> void:
	var dir := (target - caster.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var p: Projectile = SCENE.instantiate()
	p.caster = caster
	p.direction = dir
	p.speed = speed
	p.max_range = range_by_level[level]
	p.damage = 0.0
	p.knockback = 0.0
	p.on_hit = SwapSpell.trade
	p.hit_kind = "swap"
	p.position = caster.global_position + dir * 14.0
	caster.get_parent().add_child(p)
	Sfx.play_at("swap", caster.global_position, -4.0)


## The orb `p` hit `w`: its (current) owner and `w` trade places.
static func trade(p: Projectile, w: Wizard) -> void:
	var a := p.caster
	if a == null or not is_instance_valid(a) or not a.alive:
		return
	var pa := a.global_position
	var pb := w.global_position
	for wiz: Wizard in [a, w]:
		wiz.global_position = pb if wiz == a else pa
		wiz.knockback = Vector2.ZERO
		wiz.move_target = null
		wiz.reset_physics_interpolation()
	var fx_parent := a.get_parent()
	EffectOneShot.spawn_at_feet(PUFF, fx_parent, pa)
	EffectOneShot.spawn_at_feet(PUFF, fx_parent, pb)
	# Visual review 2026-11-27: the trade read as a camera glitch. A bright
	# line joins the two spots for a moment, with a flash at each end.
	var hand := Vector2(0, -14)
	FlashFx.beam(fx_parent, pa + hand, pb + hand, Color(1.0, 0.45, 0.75))
	FlashFx.ring(fx_parent, pa + hand, Color(1.0, 0.45, 0.75), 20.0)
	FlashFx.ring(fx_parent, pb + hand, Color(1.0, 0.82, 0.3), 20.0)
	Sfx.play_at("swap", pb)
