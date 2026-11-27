class_name StaffStrikeSpell
extends Spell
## A: the auto-attack. A quick staff swing in front of the wizard: short
## reach, small damage, a solid shove (handy for finishing someone off at
## the lava's edge). The cooldown is the swing itself, so holding attack
## swings back to back. Walking after the hit lands cuts the follow-through.

const SWING := preload("res://assets/sprites/effects/staff_swing_frames.tres")

@export var damage_by_level: Array[float] = [2.0, 2.5, 3.0, 4.0]
@export var knockback_by_level: Array[float] = [300.0, 330.0, 360.0, 390.0]
## Blink -> staff combo (every wizard): a hit within this many seconds of
## your own Blink pushes this much harder, with a bigger arc.
const COMBO_WINDOW := 1.5
const COMBO_KNOCKBACK := 1.4

## Auto-attack walks this close (centre to centre) before swinging.
@export var attack_range := 30.0
## The hit area is a circle this far in front of the caster...
@export var hit_offset := 16.0
## ...with this radius.
@export var hit_radius := 20.0


func _init() -> void:
	spell_name = "Staff"
	icon = SWING.get_frame_texture("default", 3)
	cooldown_by_level = [0.5, 0.5, 0.5, 0.5]
	cast_time = 0.5 # = the attack animation, so swings chain cleanly
	release_time = 0.24 # the frame where the staff comes down
	anim = "attack"
	anim_fits_cast = true
	cancel_on_move = true


static func combo_open(w: Wizard) -> bool:
	return GameClock.now() - w.last_blink_at <= COMBO_WINDOW


func release(target: Vector2) -> void:
	Sfx.play_at("staff", caster.global_position)
	var combo := combo_open(caster)
	var kb: float = knockback_by_level[level] * (COMBO_KNOCKBACK if combo else 1.0)
	var from := caster.global_position
	var dir := (target - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.from_angle(Wizard.DIRS.find(caster.facing) * PI / 4.0)
	var center := from + dir * hit_offset
	for node in caster.get_tree().get_nodes_in_group("props"):
		var rock := node as Prop
		if rock.global_position.distance_to(center) <= hit_radius + rock.radius:
			rock.push((rock.global_position - from).normalized() * knockback_by_level[level], caster)
	for node in caster.get_tree().get_nodes_in_group("wizards"):
		var w := node as Wizard
		if w == caster or not w.alive:
			continue
		var shielded := w.is_shielded()
		var hit_reach := hit_radius + (Wizard.SHIELD_RADIUS - 8.0 if shielded else 0.0)
		if w.global_position.distance_to(center) > hit_reach:
			continue
		var push := w.global_position - from
		push = push.normalized() if push.length() > 1.0 else dir
		if shielded:
			# The staff bounces off the bubble and the attacker staggers back.
			w.bubble_flash()
			caster.apply_knockback(-push * knockback_by_level[level] * 0.5)
			continue
		w.take_damage(damage_by_level[level], caster)
		w.apply_knockback(push * kb)
		w.flash_hit(push)
		_spawn_hit(w.global_position, push, combo)


## The fiery arc where the staff connects, turned to face the blow.
func _spawn_hit(at: Vector2, push: Vector2, combo := false) -> void:
	var fx: EffectOneShot = load(EffectOneShot.SCENE).instantiate()
	fx.sprite_frames = SWING
	fx.offset = -SWING.get_meta("pivot_px", Vector2.ZERO)
	fx.position = at + Vector2(0, -14) - push * 10.0
	fx.rotation = push.angle()
	fx.speed_scale = 1.5
	if combo:
		fx.scale = Vector2(1.5, 1.5)
	caster.get_parent().add_child(fx)
