class_name PcBar
extends Control
## PC only (keyboard + mouse): a command bar along the bottom in the spirit of
## classic RTS games, in this game's own look. Left: a frame for the minimap.
## Centre: health, gold and round. Right: the spell card, square icons with
## the hotkey in the corner, a dark clockwise cooldown sweep with the seconds
## left, and a tooltip on hover. Display only: you cast with the keys.
## Built by game.gd when Platform.touch() is false.

## Sizes (2026-11-28 feel pass: about 30% smaller than the first bar).
const BAR_H := 84.0
const ICON := 44.0
const GAP := 5.0
const PAD := 6.0
const MINIMAP := 110.0
const MAP_FRAME := MINIMAP + 12.0
## The spell card, row by row ("" = empty cell).
const CARD := [["Q", "W", "E", "R"], ["D", "F", "", "A"]]
const STARTER_DESC := {
	"Fireball": "Fire bolt that burns and knocks back.",
	"Blink": "Teleport a short way toward the cursor.",
	"Lightning": "Fast bolt that hits the first warlock in line.",
	"Shield": "Brief barrier that reflects spells.",
	"Staff": "Swing your staff at a warlock beside you.",
}
const HAUNT_DESC := "Shove warlocks near your ghost. No damage."

const C_STONE := Color(0.1, 0.07, 0.06, 0.97)
const C_BRONZE := Color(0.78, 0.5, 0.22)
const C_LIGHT := Color(0.42, 0.3, 0.21)
const C_DARK := Color(0.02, 0.01, 0.01)
const C_SOCKET := Color(0.05, 0.035, 0.03)
const C_PANEL := Color(0.14, 0.1, 0.08, 0.98)
const C_READY := Color(1.0, 0.6, 0.2, 0.95)
const C_TEXT := Color(1.0, 0.93, 0.85)
const C_GOLD := Color(1.0, 0.8, 0.3)
const C_HP := Color(0.85, 0.2, 0.15)

var game: Node

var _tip: PanelContainer
var _tip_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.04, 0.04, 0.95)
	sb.border_color = C_BRONZE
	sb.set_border_width_all(2)
	sb.set_content_margin_all(10)
	_tip.add_theme_stylebox_override("panel", sb)
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_label = Label.new()
	_tip_label.add_theme_font_size_override("font_size", 15)
	_tip_label.add_theme_color_override("font_color", C_TEXT)
	_tip.add_child(_tip_label)
	_tip.visible = false
	add_child(_tip)


func _process(_delta: float) -> void:
	queue_redraw()
	_update_tooltip()


# --- layout (local = viewport pixels; the bar fills the screen) -------------

func strip_rect() -> Rect2:
	return Rect2(0, size.y - BAR_H, size.x, BAR_H)


func map_frame_rect() -> Rect2:
	return Rect2(PAD, size.y - PAD - MAP_FRAME, MAP_FRAME, MAP_FRAME)


## The spell card's frame, bottom right (it rises above the strip).
func card_rect() -> Rect2:
	var w := 4 * ICON + 3 * GAP + 2 * PAD
	var h := 2 * ICON + GAP + 2 * PAD
	return Rect2(size.x - PAD - w, size.y - PAD - h, w, h)


func centre_rect() -> Rect2:
	var left := map_frame_rect().end.x + 12.0
	var right := card_rect().position.x - 12.0
	var w := minf(right - left, 340.0)
	return Rect2((left + right - w) / 2.0, size.y - BAR_H + PAD, w, BAR_H - 2 * PAD)


func slot_rect(slot: String) -> Rect2:
	var card := card_rect()
	for row in CARD.size():
		var col: int = CARD[row].find(slot)
		if col >= 0:
			return Rect2(card.position + Vector2(PAD + col * (ICON + GAP), PAD + row * (ICON + GAP)),
					Vector2(ICON, ICON))
	return Rect2()


## Where the minimap sits (centred in its frame).
func minimap_position() -> Vector2:
	return map_frame_rect().get_center() - Vector2(MINIMAP, MINIMAP) / 2.0


func slot_at(pos: Vector2) -> String:
	for row in CARD:
		for slot in row:
			if slot != "" and slot_rect(slot).has_point(pos):
				return slot
	return ""


## Over the bar: right-clicks here must not walk the warlock.
func blocks_mouse(pos: Vector2) -> bool:
	if not visible:
		return false
	return strip_rect().has_point(pos) or map_frame_rect().has_point(pos) or card_rect().has_point(pos)


# --- content ----------------------------------------------------------------

func _player() -> Wizard:
	return game.player if game else null


func _ghost() -> Ghost:
	return game.ghost if game else null


## Drawn with an icon: the slot's spell exists; while a ghost only A (Haunt).
func shown(slot: String) -> bool:
	var p := _player()
	if p == null or p.get_spell(slot) == null:
		return false
	return slot == "A" if _ghost() != null else true


func _ratio(slot: String) -> float:
	if _ghost() != null and slot == "A":
		return _ghost().cooldown_ratio()
	return _player().get_spell(slot).cooldown_ratio()


func _seconds_left(slot: String) -> float:
	if _ghost() != null and slot == "A":
		return _ghost().haunt_left
	return _player().get_spell(slot).cooldown_left


func tooltip_text(slot: String) -> String:
	if not shown(slot):
		return ""
	if _ghost() != null:
		return "Haunt  [%s]\n%s\nCooldown %ss" % [slot, HAUNT_DESC, _num(Ghost.HAUNT_COOLDOWN)]
	var spell := _player().get_spell(slot)
	var desc: String = STARTER_DESC.get(spell.spell_name, "")
	if spell.spell_id != "" and Shop.SPELLS.has(spell.spell_id):
		desc = Shop.SPELLS[spell.spell_id].get("desc", desc)
	var cd: float = spell.cooldown_by_level[spell.level]
	return "%s  [%s]\n%s\nCooldown %ss" % [spell.spell_name, slot, desc, _num(cd)]


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


func _update_tooltip() -> void:
	var slot := slot_at(get_local_mouse_position()) if visible else ""
	var text := tooltip_text(slot) if slot != "" else ""
	_tip.visible = text != ""
	if text == "":
		return
	_tip_label.text = text
	_tip.reset_size()
	var card := card_rect()
	_tip.position = Vector2(card.end.x - _tip.size.x, card.position.y - 6.0 - _tip.size.y)


# --- drawing ----------------------------------------------------------------

func _draw() -> void:
	if game == null:
		return
	var strip := strip_rect()
	draw_rect(strip, C_STONE)
	draw_rect(Rect2(strip.position, Vector2(strip.size.x, 2)), C_BRONZE)
	_frame(map_frame_rect())
	draw_rect(map_frame_rect().grow(-PAD + 2), C_DARK)
	_frame(card_rect())
	_frame(centre_rect())
	_draw_centre(centre_rect())
	var font := get_theme_default_font()
	for row in CARD:
		for slot in row:
			if slot != "":
				_draw_slot(slot, font)


## A raised frame: bronze outline, light top-left edge, dark bottom-right.
func _frame(r: Rect2) -> void:
	draw_rect(r, C_PANEL)
	draw_rect(r, C_BRONZE, false, 2.0)
	var i := r.grow(-3)
	draw_line(i.position, Vector2(i.end.x, i.position.y), C_LIGHT, 2.0)
	draw_line(i.position, Vector2(i.position.x, i.end.y), C_LIGHT, 2.0)
	draw_line(Vector2(i.position.x, i.end.y), i.end, C_DARK, 2.0)
	draw_line(Vector2(i.end.x, i.position.y), i.end, C_DARK, 2.0)


func _draw_slot(slot: String, font: Font) -> void:
	var r := slot_rect(slot)
	# Recessed socket: dark top-left edge, light bottom-right.
	draw_rect(r.grow(2), C_SOCKET)
	draw_line(r.position - Vector2(2, 2), Vector2(r.end.x + 2, r.position.y - 2), C_DARK, 2.0)
	draw_line(r.position - Vector2(2, 2), Vector2(r.position.x - 2, r.end.y + 2), C_DARK, 2.0)
	draw_line(Vector2(r.position.x - 2, r.end.y + 2), r.end + Vector2(2, 2), C_LIGHT, 1.0)
	draw_line(Vector2(r.end.x + 2, r.position.y - 2), r.end + Vector2(2, 2), C_LIGHT, 1.0)
	if not shown(slot):
		return
	var spell := _player().get_spell(slot)
	draw_rect(r, Color(0.2, 0.14, 0.11))
	if spell.icon:
		_draw_icon(spell.icon, r.grow(-4), spell.icon_tint if _ghost() == null else Ghost.TINT)
	var ratio := _ratio(slot)
	if ratio > 0.0:
		_draw_sweep(r, ratio, Color(0, 0, 0, 0.68))
		var secs := _seconds_left(slot)
		var t := str(ceili(secs)) if secs >= 1.0 else "%.1f" % secs
		draw_string_outline(font, Vector2(r.position.x, r.get_center().y + 6), t,
				HORIZONTAL_ALIGNMENT_CENTER, ICON, 18, 4, Color.BLACK)
		draw_string(font, Vector2(r.position.x, r.get_center().y + 8), t,
				HORIZONTAL_ALIGNMENT_CENTER, ICON, 18, C_TEXT)
	else:
		draw_rect(r.grow(-1), C_READY, false, 2.0)
	# Hotkey letter, top-left corner.
	draw_rect(Rect2(r.position, Vector2(13, 14)), Color(0, 0, 0, 0.7))
	draw_string(font, r.position + Vector2(2, 11), slot, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_TEXT)


func _draw_icon(tex: Texture2D, box: Rect2, tint: Color) -> void:
	var s := tex.get_size()
	var k := minf(box.size.x / s.x, box.size.y / s.y)
	var fit := s * k
	draw_texture_rect(tex, Rect2(box.get_center() - fit / 2.0, fit), false, tint)


## Dark square sweep covering `ratio` of the icon, clockwise from the top.
func _draw_sweep(r: Rect2, ratio: float, col: Color) -> void:
	var c := r.get_center()
	var half := r.size.x / 2.0
	var pts := PackedVector2Array([c])
	var steps := maxi(4, ceili(48 * ratio))
	for i in steps + 1:
		var a := -PI / 2.0 + TAU * ratio * float(i) / steps
		var d := Vector2(cos(a), sin(a))
		pts.append(c + d * half / maxf(absf(d.x), absf(d.y)))
	if pts.size() >= 3:
		draw_colored_polygon(pts, col)


func _draw_centre(r: Rect2) -> void:
	var p := _player()
	if p == null:
		return
	var font := get_theme_default_font()
	var inner := r.grow(-8)
	# Health bar.
	var hp := Rect2(inner.position + Vector2(0, 2), Vector2(inner.size.x, 20))
	draw_rect(hp, C_DARK)
	var frac := clampf(p.health / p.max_health, 0.0, 1.0) if p.alive else 0.0
	draw_rect(Rect2(hp.position, Vector2(hp.size.x * frac, hp.size.y)), C_HP)
	draw_rect(Rect2(hp.position, Vector2(hp.size.x * frac, 4)), Color(1, 0.5, 0.4, 0.5))
	draw_rect(hp, C_BRONZE, false, 1.0)
	var hp_text := "%d / %d" % [ceili(p.health), int(p.max_health)] if p.alive else "Ghost"
	draw_string_outline(font, hp.position + Vector2(0, 15), hp_text, HORIZONTAL_ALIGNMENT_CENTER,
			hp.size.x, 14, 4, Color.BLACK)
	draw_string(font, hp.position + Vector2(0, 15), hp_text, HORIZONTAL_ALIGNMENT_CENTER, hp.size.x, 14, C_TEXT)
	# Gold and round.
	var y := hp.end.y + 24
	var gold: int = game.gold.get(p, 0)
	draw_string(font, Vector2(inner.position.x, y), "Gold %d" % gold, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_GOLD)
	var rn: int = game.round_number
	draw_string(font, Vector2(inner.position.x, y), "Round %d" % rn if rn > 0 else "", HORIZONTAL_ALIGNMENT_RIGHT,
			inner.size.x, 16, C_TEXT)
