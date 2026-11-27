class_name TouchControls
extends Control
## On-screen controls for phones.
## - Left half: a floating joystick appears where the thumb lands; drag to walk.
##   The ring follows the thumb if it goes past the edge (so a reversal is
##   instant). Touchpad mode (setting): no ring, the whole left half is a pad
##   and any small slide walks at full speed that way (it trails the thumb
##   closely). A thumb put down between rounds is kept and walks at the start.
## - Bottom right, big: staff attack. Swings on the spot (it never walks you
##   anywhere), turned toward the nearest enemy if one is close, else the way
##   you face. Hold to keep swinging. A small timer shows the cooldown.
## - Around it: spell buttons. Drag a button to aim (a guide shows in the
##   arena), release to cast. A quick tap auto-aims: at the nearest enemy in
##   the spell's range (on-screen ones first), leading a walker for
##   fireballs; if nobody is in range, toward the nearest enemy anyway.
##   Drag back onto the button before releasing to cancel. Shield casts on touch.
## Works with a mouse too (project setting emulate_touch_from_mouse).

const STICK_R := 80.0 ## how far the knob can travel
const STICK_DEAD := 0.15 ## fraction of STICK_R; speed ramps up from here
const PAD_R := 24.0 ## touchpad: how far the origin trails behind the thumb
const PAD_DEAD := 8.0 ## touchpad: slide this far (px) to start walking
const AIM_DEAD := 22.0 ## drag shorter than this = tap (auto-aim)
const AIM_FULL := 110.0 ## drag length for full blink distance
const MARGIN := 34.0
const INSTANT_SLOTS := ["R"]
## The attack turns toward an enemy this close (world px); further away it
## swings the way you face.
const ATTACK_AIM_ASSIST := 70.0
## Button layout: the attack button bottom right, spells in an arc round it
## (radius 170, every 32 degrees from straight left to straight up).
const LAYOUT := {
	"A": {"offset": Vector2.ZERO, "r": 64.0},
	"Q": {"offset": Vector2(-170, 0), "r": 44.0},
	"W": {"offset": Vector2(-144, -90), "r": 44.0},
	"E": {"offset": Vector2(-74, -153), "r": 44.0},
	"R": {"offset": Vector2(18, -169), "r": 44.0},
	# The two shop slots (any bought spell): left of Q, and up-left of W;
	# only drawn once something is bought.
	"D": {"offset": Vector2(-266, 0), "r": 44.0},
	"F": {"offset": Vector2(-246, -106), "r": 44.0},
}

var wizard: Wizard
## True between rounds (countdown, results): no moving or casting, and
## new touches pass through to the HUD (e.g. the Play again button).
var locked := false
## Touchpad movement instead of the joystick (GameSettings.move_mode).
var touchpad := false
## While the player is a ghost: the attack button haunts, spells are hidden.
var ghost: Ghost
## Tapped while a ghost: the ghost teleports there.
var minimap: Minimap

var _stick_index := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _aim_index := -1
var _aim_slot := ""
var _aim_vec := Vector2.ZERO
var _attack_index := -1
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
		wizard.move_target = null
		wizard.move_dir = Vector2.ZERO if locked else stick_vector()
	if wizard and _attack_index >= 0:
		_hold_attack()
	_update_guide()
	queue_redraw()


## Walk direction from the thumb: length 0-1 for the joystick (ramps up from
## the deadzone edge), full speed for the touchpad.
func stick_vector() -> Vector2:
	var off := _stick_pos - _stick_origin
	if touchpad:
		return off.normalized() if off.length() > PAD_DEAD else Vector2.ZERO
	var k := off.length() / STICK_R
	if k <= STICK_DEAD:
		return Vector2.ZERO
	return off.normalized() * minf((k - STICK_DEAD) / (1.0 - STICK_DEAD), 1.0)


func _notification(what: int) -> void:
	# Leaving the app (home, notification shade, a call) can swallow touch-ups.
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		release_all()


## Forget every finger (pausing: touch-ups won't arrive while paused).
func release_all() -> void:
	_stick_index = -1
	_aim_index = -1
	_aim_slot = ""
	_attack_index = -1
	if wizard:
		wizard.move_dir = Vector2.ZERO


# --- input ------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if wizard == null:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and not t.canceled:
			if not locked:
				_touch_down(t.index, t.position)
			elif _is_stick_spot(t.position):
				# Between rounds: remember the thumb (it walks once the fight
				# starts) but let the touch reach the HUD too.
				_grab_stick(t.index, t.position)
		else:
			_touch_up(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_index:
			_move_stick(d.position)
		elif d.index == _aim_index:
			_aim_vec = d.position - _button_center(_aim_slot)


func _touch_down(index: int, pos: Vector2) -> void:
	if ghost != null and minimap != null:
		var spot: Variant = minimap.world_at(pos)
		if spot != null:
			get_viewport().set_input_as_handled()
			ghost.teleport(spot)
			return
	var slot := _button_at(pos)
	if slot != "":
		get_viewport().set_input_as_handled()
		if ghost != null:
			if slot == "A" and ghost.haunt():
				_flash["A"] = 0.15
			return
		if slot == "A":
			if _attack_index < 0:
				_attack_index = index
				_hold_attack()
		elif slot in INSTANT_SLOTS:
			_cast(slot, Vector2.ZERO, true)
		elif _aim_index < 0:
			_aim_index = index
			_aim_slot = slot
			_aim_vec = Vector2.ZERO
		return
	if _is_stick_spot(pos):
		# A new thumb always takes the stick, even if an old touch never
		# reported its release (else the stick would stay dead).
		get_viewport().set_input_as_handled()
		_grab_stick(index, pos)


func _is_stick_spot(pos: Vector2) -> bool:
	return pos.x < size.x * 0.5 and _button_at(pos) == ""


func _grab_stick(index: int, pos: Vector2) -> void:
	_stick_index = index
	_stick_origin = pos
	_stick_pos = pos


## Thumb moved: past the ring (or the touchpad's short leash) the origin is
## dragged along, so turning around answers at once.
func _move_stick(pos: Vector2) -> void:
	var leash := PAD_R if touchpad else STICK_R
	var off := pos - _stick_origin
	if off.length() > leash:
		_stick_origin = pos - off.normalized() * leash
	_stick_pos = pos


func _touch_up(index: int) -> void:
	if index == _attack_index:
		_attack_index = -1
	elif index == _stick_index:
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


## Called every frame while the attack button is held: swing whenever the
## staff is ready, on the spot.
func _hold_attack() -> void:
	if not wizard.alive or locked:
		return
	var aim := wizard.global_position + _facing_vec() * 20.0
	var near := _nearest_enemy()
	if near and near.global_position.distance_to(wizard.global_position) <= ATTACK_AIM_ASSIST:
		aim = near.global_position
	if wizard.cast("A", aim):
		_flash["A"] = 0.15


func _cast(slot: String, aim_vec: Vector2, tapped: bool) -> void:
	if locked:
		return
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
		var enemy := _auto_target(_reach(spell))
		if enemy == null:
			return p + _facing_vec() * _reach(spell)
		if spell is FireballSpell:
			return _lead(enemy, (spell as FireballSpell).speed)
		return enemy.global_position
	var reach := _reach(spell)
	if slot == "W" or spell.placed:
		reach *= clampf(aim_vec.length() / AIM_FULL, 0.25, 1.0)
	return p + aim_vec.normalized() * reach


func _reach(spell: Spell) -> float:
	if spell is BlinkSpell:
		return spell.max_distance
	if spell is LightningSpell:
		return spell.max_range
	if spell is FireballSpell:
		return spell.max_range
	return spell.reach()


## Tap target for a spell that reaches `reach` px: the closest enemy in
## range, where enemies off-screen count as further away than they are (you
## mean the one you can see). Nobody in range: the nearest enemy anyway.
func _auto_target(reach: float) -> Wizard:
	var best: Wizard = null
	var best_score := INF
	var screen := get_viewport().get_visible_rect()
	var to_screen := get_viewport().get_canvas_transform()
	for n in get_tree().get_nodes_in_group("wizards"):
		var w := n as Wizard
		if w == wizard or not w.alive:
			continue
		var d := w.global_position.distance_to(wizard.global_position)
		if d > reach:
			continue
		var score := d if screen.has_point(to_screen * w.global_position) else d + 400.0
		if score < best_score:
			best = w
			best_score = score
	return best if best else _nearest_enemy()


## Where to throw a projectile of `speed` so it meets `w` if they keep walking.
func _lead(w: Wizard, speed: float) -> Vector2:
	var at := w.global_position
	var t := wizard.global_position.distance_to(at) / speed
	return at + w.velocity * t


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
	var spell := wizard.get_spell(_aim_slot)
	_guide.area = spell.area_radius if spell else 0.0
	_guide.cancel = cancel
	_guide.queue_redraw()


# --- layout & drawing ---------------------------------------------------------

func _button_center(slot: String) -> Vector2:
	var q_r: float = LAYOUT.A.r
	var base := size - Vector2(MARGIN + q_r + 24.0, MARGIN + q_r)
	return base + LAYOUT[slot].offset


func _button_at(pos: Vector2) -> String:
	for slot in LAYOUT:
		if _shown(slot) and pos.distance_to(_button_center(slot)) <= LAYOUT[slot].r + 12.0:
			return slot
	return ""


func _draw() -> void:
	if wizard == null:
		return
	# Joystick (a faint hint where it usually sits when not touched).
	if touchpad:
		if _stick_index >= 0:
			draw_circle(_stick_pos, 18.0, Color(1, 0.75, 0.5, 0.25))
	elif _stick_index >= 0:
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
		if not _shown(slot):
			continue
		var c := _button_center(slot)
		var r: float = LAYOUT[slot].r
		var held: bool = slot == _aim_slot or (slot == "A" and _attack_index >= 0)
		draw_circle(c, r, Color(0.1, 0.06, 0.06, 0.8 if held else 0.65), true, -1.0, true)
		if spell.icon:
			var s := spell.icon.get_size()
			var box := r * 1.25
			var k := box / maxf(s.x, s.y)
			draw_texture_rect(spell.icon, Rect2(c - s * k / 2.0, s * k), false, spell.icon_tint)
		var cd := spell.cooldown_ratio()
		if ghost != null:
			cd = ghost.cooldown_ratio()
			if cd > 0.0:
				_draw_pie(c, r, cd, Color(0, 0, 0, 0.6))
			draw_arc(c, r, 0, TAU, 48, Color(0.7, 0.9, 1.0, 0.9 if cd == 0.0 else 0.4), 4.0, true)
			draw_string(font, c + Vector2(-r, r * 0.72), "Haunt", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 18, Color(0.85, 0.95, 1.0))
			continue
		if cd > 0.0 and slot == "A":
			# Attack: quick, so a thin ring that runs down plus a small timer.
			draw_arc(c, r - 3.0, -PI / 2.0, -PI / 2.0 + TAU * cd, 48, Color(1, 0.85, 0.6, 0.9), 5.0, true)
			draw_string(font, c + Vector2(-r, r * 0.72), "%.1f" % spell.cooldown_left,
					HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 18, Color(1, 0.92, 0.82))
		elif cd > 0.0:
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
## Drawn and touchable: owned spells; only the attack (haunt) for a ghost.
func _shown(slot: String) -> bool:
	return wizard.get_spell(slot) != null and (ghost == null or slot == "A")


func _draw_pie(c: Vector2, r: float, ratio: float, col: Color) -> void:
	ratio = minf(ratio, 1.0)
	if ratio < 0.01:
		return # a sliver would be a degenerate polygon
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
	## > 0: a placed spell -- draw the ground it will cover instead of an arrow.
	var area := 0.0
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
		if area > 0.0:
			var ring := PackedVector2Array()
			for i in 33:
				var a := i * TAU / 32.0
				ring.append(target + Vector2(cos(a) * area, sin(a) * area * 0.62))
			draw_polyline(ring, col, 2.0)
		elif blink:
			draw_arc(target, 10.0, 0, TAU, 20, col, 2.0)
		else:
			var d := (to - hand).normalized()
			draw_line(to, to - d.rotated(0.5) * 9.0, col, 2.0)
			draw_line(to, to - d.rotated(-0.5) * 9.0, col, 2.0)
