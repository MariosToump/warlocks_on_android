class_name TouchControls
extends Control
## On-screen controls for phones.
## - Left half: a floating joystick appears where the thumb lands; drag to walk.
## - Bottom right: spell buttons. Drag a button to aim (a guide shows in the
##   arena), release to cast. A quick tap auto-aims at the nearest enemy.
##   Drag back onto the button before releasing to cancel. Shield casts on touch.
## Works with a mouse too (project setting emulate_touch_from_mouse).

const STICK_R := 80.0 ## how far the knob can travel
const STICK_DEAD := 0.15
const AIM_DEAD := 22.0 ## drag shorter than this = tap (auto-aim)
const AIM_FULL := 110.0 ## drag length for full blink distance
const MARGIN := 34.0
const INSTANT_SLOTS := ["R"]
## Button layout around the main (Q) button, bottom right.
const LAYOUT := {
	"Q": {"offset": Vector2.ZERO, "r": 62.0},
	"E": {"offset": Vector2(-158, 14), "r": 48.0},
	"W": {"offset": Vector2(-124, -112), "r": 48.0},
	"R": {"offset": Vector2(-10, -158), "r": 48.0},
}

var wizard: Wizard

var _stick_index := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _aim_index := -1
var _aim_slot := ""
var _aim_vec := Vector2.ZERO
var _flash := {} # slot -> seconds of press flash left
var _guide: AimGuide


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if wizard and _guide == null and wizard.is_inside_tree():
		_guide = AimGuide.new()
		wizard.get_parent().add_child(_guide)
	for k in _flash.keys():
		_flash[k] = maxf(_flash[k] - delta, 0.0)
	if wizard and _stick_index >= 0:
		var v := (_stick_pos - _stick_origin) / STICK_R
		wizard.move_target = null
		wizard.move_dir = v.limit_length(1.0) if v.length() > STICK_DEAD else Vector2.ZERO
	_update_guide()
	queue_redraw()


# --- input ------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if wizard == null:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touch_down(t.index, t.position)
		else:
			_touch_up(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_index:
			_stick_pos = _stick_origin + (d.position - _stick_origin).limit_length(STICK_R)
		elif d.index == _aim_index:
			_aim_vec = d.position - _button_center(_aim_slot)


func _touch_down(index: int, pos: Vector2) -> void:
	var slot := _button_at(pos)
	if slot != "":
		get_viewport().set_input_as_handled()
		if slot in INSTANT_SLOTS:
			_cast(slot, Vector2.ZERO, true)
		elif _aim_index < 0:
			_aim_index = index
			_aim_slot = slot
			_aim_vec = Vector2.ZERO
		return
	if pos.x < size.x * 0.5 and _stick_index < 0:
		get_viewport().set_input_as_handled()
		_stick_index = index
		_stick_origin = pos
		_stick_pos = pos


func _touch_up(index: int) -> void:
	if index == _stick_index:
		_stick_index = -1
		wizard.move_dir = Vector2.ZERO
	elif index == _aim_index:
		var slot := _aim_slot
		var v := _aim_vec
		_aim_index = -1
		_aim_slot = ""
		# Released back on the button after aiming = cancel.
		var r: float = LAYOUT[slot].r
		if v.length() < AIM_DEAD or v.length() > r:
			_cast(slot, v, v.length() < AIM_DEAD)


func _cast(slot: String, aim_vec: Vector2, tapped: bool) -> void:
	if wizard.cast(slot, _target_for(slot, aim_vec, tapped)):
		_flash[slot] = 0.15


# --- aiming -------------------------------------------------------------------

## World point the spell is cast at.
func _target_for(slot: String, aim_vec: Vector2, tapped: bool) -> Vector2:
	var p := wizard.global_position
	var spell := wizard.get_spell(slot)
	if tapped:
		if slot == "W": # blink: where you're heading, else where you face
			var dir := wizard.move_dir if wizard.move_dir != Vector2.ZERO else _facing_vec()
			return p + dir.normalized() * _reach(spell)
		var enemy := _nearest_enemy()
		return enemy.global_position if enemy else p + _facing_vec() * _reach(spell)
	var reach := _reach(spell)
	if slot == "W":
		reach *= clampf(aim_vec.length() / AIM_FULL, 0.25, 1.0)
	return p + aim_vec.normalized() * reach


func _reach(spell: Spell) -> float:
	if spell is BlinkSpell:
		return spell.max_distance
	if spell is LightningSpell:
		return spell.max_range
	if spell is FireballSpell:
		return 320.0 # guide length; it flies further
	return 100.0


func _nearest_enemy() -> Wizard:
	var best: Wizard = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("wizards"):
		var w := n as Wizard
		if w == wizard or not w.alive:
			continue
		var d := w.global_position.distance_squared_to(wizard.global_position)
		if d < best_d:
			best = w
			best_d = d
	return best


func _facing_vec() -> Vector2:
	return Vector2.from_angle(Wizard.DIRS.find(wizard.facing) * PI / 4.0)


func _update_guide() -> void:
	if _guide == null:
		return
	_guide.visible = _aim_index >= 0 and wizard.alive
	if not _guide.visible:
		return
	var tapped := _aim_vec.length() < AIM_DEAD
	var cancel := _aim_vec.length() <= float(LAYOUT[_aim_slot].r) and not tapped
	_guide.global_position = wizard.global_position
	_guide.target = _target_for(_aim_slot, _aim_vec, tapped) - wizard.global_position
	_guide.blink = _aim_slot == "W"
	_guide.cancel = cancel
	_guide.queue_redraw()


# --- layout & drawing ---------------------------------------------------------

func _button_center(slot: String) -> Vector2:
	var q_r: float = LAYOUT.Q.r
	var base := size - Vector2(MARGIN + q_r + 24.0, MARGIN + q_r)
	return base + LAYOUT[slot].offset


func _button_at(pos: Vector2) -> String:
	for slot in LAYOUT:
		if wizard.get_spell(slot) and pos.distance_to(_button_center(slot)) <= LAYOUT[slot].r + 12.0:
			return slot
	return ""


func _draw() -> void:
	if wizard == null:
		return
	# Joystick (a faint hint where it usually sits when not touched).
	if _stick_index >= 0:
		draw_circle(_stick_origin, STICK_R, Color(0, 0, 0, 0.25))
		draw_arc(_stick_origin, STICK_R, 0, TAU, 48, Color(1, 0.8, 0.6, 0.45), 3.0, true)
		draw_circle(_stick_pos, 34.0, Color(1, 0.75, 0.5, 0.55))
	else:
		var hint := Vector2(MARGIN + STICK_R + 30.0, size.y - MARGIN - STICK_R)
		draw_arc(hint, STICK_R, 0, TAU, 48, Color(1, 0.8, 0.6, 0.18), 3.0, true)
		draw_circle(hint, 34.0, Color(1, 0.75, 0.5, 0.15))

	var font := ThemeDB.fallback_font
	for slot in LAYOUT:
		var spell := wizard.get_spell(slot)
		if spell == null:
			continue
		var c := _button_center(slot)
		var r: float = LAYOUT[slot].r
		var held: bool = slot == _aim_slot
		draw_circle(c, r, Color(0.1, 0.06, 0.06, 0.8 if held else 0.65), true, -1.0, true)
		if spell.icon:
			var s := spell.icon.get_size()
			var box := r * 1.25
			var k := box / maxf(s.x, s.y)
			draw_texture_rect(spell.icon, Rect2(c - s * k / 2.0, s * k), false)
		var cd := spell.cooldown_ratio()
		if cd > 0.0:
			_draw_pie(c, r, cd, Color(0, 0, 0, 0.6))
			draw_string(font, c + Vector2(-r, 9), "%.1f" % spell.cooldown_left,
					HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 26, Color(1, 0.92, 0.82))
			draw_arc(c, r, 0, TAU, 48, Color(0.4, 0.3, 0.3, 0.8), 3.0, true)
		else:
			var glow := 1.0 if held or _flash.get(slot, 0.0) > 0.0 else 0.85
			draw_arc(c, r, 0, TAU, 48, Color(1, 0.6, 0.2, glow), 4.0, true)
		if held and _aim_vec.length() >= AIM_DEAD:
			# Thumb position, so you can see where you're dragging.
			draw_circle(c + _aim_vec.limit_length(r + 60.0), 14.0, Color(1, 0.8, 0.5, 0.5))


## Cooldown shade: a pie slice covering `ratio` of the button, clockwise from top.
func _draw_pie(c: Vector2, r: float, ratio: float, col: Color) -> void:
	var pts := PackedVector2Array([c])
	var steps := maxi(int(48 * ratio), 2)
	for i in steps + 1:
		var a := -PI / 2.0 + TAU * ratio * float(i) / steps
		pts.append(c + Vector2.from_angle(a) * r)
	draw_colored_polygon(pts, col)


## Drawn in the arena while aiming: a dashed line to the target, or a ring
## where a blink lands. Red-ish when releasing would cancel.
class AimGuide extends Node2D:
	var target := Vector2.ZERO
	var blink := false
	var cancel := false

	func _ready() -> void:
		z_index = 4
		visible = false

	func _draw() -> void:
		var col := Color(1, 0.35, 0.3, 0.5) if cancel else Color(1, 0.9, 0.7, 0.75)
		var hand := Vector2(0, -16)
		var to := target + hand
		var n := int(to.distance_to(hand) / 12.0)
		for i in n:
			if i % 2 == 0:
				draw_line(hand.lerp(to, float(i) / n), hand.lerp(to, float(i + 1) / n), col, 2.0)
		if blink:
			draw_arc(target, 10.0, 0, TAU, 20, col, 2.0)
		else:
			var d := (to - hand).normalized()
			draw_line(to, to - d.rotated(0.5) * 9.0, col, 2.0)
			draw_line(to, to - d.rotated(-0.5) * 9.0, col, 2.0)
