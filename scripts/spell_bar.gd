class_name SpellBar
extends Control
## Placeholder spell bar: Q W E R D F slots with icon, key and cooldown.
## Swapped for PixelLab UI art in the polish milestone.

const SLOTS := ["Q", "W", "E", "R", "D", "F"]
const SIZE := 40
const GAP := 6

var wizard: Wizard


func _ready() -> void:
	custom_minimum_size = Vector2(SLOTS.size() * (SIZE + GAP) - GAP, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for i in SLOTS.size():
		var slot: String = SLOTS[i]
		var r := Rect2(i * (SIZE + GAP), 0, SIZE, SIZE)
		var spell: Spell = wizard.get_spell(slot) if wizard else null
		draw_rect(r.grow(2), Color(0.05, 0.03, 0.03, 0.9))
		draw_rect(r, Color(0.16, 0.12, 0.12, 0.9) if spell else Color(0.08, 0.07, 0.07, 0.7))
		if spell:
			if spell.icon:
				_draw_icon(spell.icon, r.grow(-3))
			var cd := spell.cooldown_ratio()
			if cd > 0.0:
				var h := roundf(SIZE * cd)
				draw_rect(Rect2(r.position.x, r.position.y + SIZE - h, SIZE, h), Color(0, 0, 0, 0.65))
				draw_string(font, r.position + Vector2(0, 26), "%.1f" % spell.cooldown_left,
						HORIZONTAL_ALIGNMENT_CENTER, SIZE, 13, Color(1, 0.9, 0.8))
			else:
				draw_rect(r, Color(1, 0.6, 0.2, 0.9), false, 1.0)
		draw_string(font, r.position + Vector2(3, 12), slot, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
				Color(1, 1, 1, 0.9 if spell else 0.35))


func _draw_icon(tex: Texture2D, box: Rect2) -> void:
	var s := tex.get_size()
	var k := minf(box.size.x / s.x, box.size.y / s.y)
	var fit := s * k
	draw_texture_rect(tex, Rect2(box.get_center() - fit / 2.0, fit), false)
