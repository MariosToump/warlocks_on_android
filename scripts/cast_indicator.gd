class_name CastIndicator
extends Node2D
## PC smart cast (2026-11-28): while a spell key is held, shows what the spell
## will cover before you let go: a faint ring for its range, plus a lane for
## projectiles and Lightning (its tip highlighted), a landing circle for
## Blink, or the area for placed spells. Grey while the spell recharges.
## Lives in the world (top_level), drawn around the caster.

## Lane half-widths: the projectile's radius plus a wizard body (7).
const BODY := 7.0
const HAND := Vector2(0, -16) ## spells leave from the hand, as in the touch guide
const COL := Color(1.0, 0.85, 0.6)
const COL_GREY := Color(0.6, 0.6, 0.6)

var spell: Spell
var mouse := Vector2.ZERO ## world position of the mouse


func _ready() -> void:
	top_level = true
	z_index = 4
	visible = false


## Shield and Dark Mirror have nothing to aim: they cast on key down.
static func instant(s: Spell) -> bool:
	return s is ShieldSpell or s is DarkMirrorSpell


## How far the spell reaches from the caster (same rule as the touch guide).
static func reach_of(s: Spell) -> float:
	if s is BlinkSpell:
		return (s as BlinkSpell).max_distance
	if s is LightningSpell:
		return (s as LightningSpell).max_range
	if s is FireballSpell:
		return (s as FireballSpell).max_range
	if s is HomingOrbSpell:
		return (s as HomingOrbSpell).max_range
	return s.reach()


static func lane_half_width(s: Spell) -> float:
	if s is LightningSpell:
		return (s as LightningSpell).hit_width
	if s is BoomerangSpell:
		return 9.0 + BODY
	return 7.0 + BODY


func show_for(s: Spell, caster: Wizard, mouse_world: Vector2) -> void:
	spell = s
	mouse = mouse_world
	global_position = caster.global_position
	visible = true
	queue_redraw()


func hide_now() -> void:
	visible = false
	spell = null


func _draw() -> void:
	if spell == null:
		return
	var col := COL if spell.is_ready() else COL_GREY
	var reach := reach_of(spell)
	var to := mouse - global_position
	var dir := to.normalized() if to.length() > 1.0 else Vector2.RIGHT
	draw_arc(Vector2.ZERO, reach, 0, TAU, 64, Color(col, 0.28), 1.5, true)
	if spell is BlinkSpell or spell.placed:
		var at := to.limit_length(reach)
		draw_line(HAND, at, Color(col, 0.35), 1.5, true)
		if spell.placed:
			_ellipse(at, spell.area_radius, col)
		else:
			draw_circle(at, 10.0, Color(col, 0.18))
			draw_arc(at, 10.0, 0, TAU, 24, Color(col, 0.8), 2.0, true)
		return
	var half := lane_half_width(spell)
	if spell is LightningSpell:
		var tip := (spell as LightningSpell).tip_length
		_lane(HAND, dir, reach - tip, half, col, 0.16)
		_lane(HAND + dir * (reach - tip), dir, tip, (spell as LightningSpell).tip_width, col, 0.32)
	else:
		_lane(HAND, dir, reach, half, col, 0.16)


## A rectangle `length` long from `from` along `dir`, `half` wide each side.
func _lane(from: Vector2, dir: Vector2, length: float, half: float, col: Color, fill: float) -> void:
	var side := dir.orthogonal() * half
	var end := from + dir * length
	var pts := PackedVector2Array([from + side, end + side, end - side, from - side])
	draw_colored_polygon(pts, Color(col, fill))
	pts.append(pts[0])
	draw_polyline(pts, Color(col, 0.7), 1.5, true)


## The ground a placed spell covers (squashed like the touch guide's ring).
func _ellipse(at: Vector2, r: float, col: Color) -> void:
	var ring := PackedVector2Array()
	for i in 41:
		var a := i * TAU / 40.0
		ring.append(at + Vector2(cos(a) * r, sin(a) * r * 0.62))
	draw_colored_polygon(ring.slice(0, 40), Color(col, 0.16))
	draw_polyline(ring, Color(col, 0.8), 2.0, true)
