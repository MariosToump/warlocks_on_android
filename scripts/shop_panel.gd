class_name ShopPanel
extends Control
## The between-rounds shop for the player: spell upgrades, new spells (two
## slots), and items (max 2, sell for half). Opens on game.shop_opened, closes
## on Ready or when the timer runs out. Item icons are drawn in code.
## Layout (v0.12 fix): fills the screen with a margin, three columns (your
## spells | new spells | items) in a ScrollContainer, so it never runs off a
## phone screen; on a 1280x720 or wider screen nothing needs scrolling.

const MARGIN := 12

var game: Node
var ready_button: Button
var scroll: ScrollContainer

var _dim: ColorRect
var _gold: Label
var _timer: Label
var _spells_box: VBoxContainer
var _new_box: VBoxContainer
var _items_box: VBoxContainer
var _items_title: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.05, 0.95)
	sb.border_color = Color(1.0, 0.45, 0.15)
	sb.set_border_width_all(3)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	_dim.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, MARGIN)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	root.add_child(head)
	head.add_child(_label("Shop", 30))
	_gold = _label("", 22, Color(1, 0.8, 0.3))
	_gold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_gold)
	_timer = _label("", 22)
	head.add_child(_timer)
	ready_button = _button("Ready", _on_ready, Vector2(150, 48))
	head.add_child(ready_button)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cols)
	_spells_box = _column(cols, "Your spells")
	_new_box = _column(cols, "New spells (2 slots)")
	_items_box = _column(cols, "")
	_items_title = _items_box.get_parent().get_child(0)

	visible = false


func _column(cols: HBoxContainer, title: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(col)
	col.add_child(_label(title, 20, Color(1, 0.6, 0.25)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	col.add_child(box)
	return box


func setup(g: Node) -> void:
	game = g
	game.shop_opened.connect(open)
	game.shop_closed.connect(_close)


func open() -> void:
	visible = true
	game.pause_menu.set_pause_button(false) # the panel fills the screen; Ready / the timer end it
	refresh()


func _close() -> void:
	visible = false
	game.pause_menu.set_pause_button(true)


func _process(_delta: float) -> void:
	if visible and game:
		_timer.text = "%d s" % ceili(game.state_left)


func _on_ready() -> void:
	Sfx.play("click")
	game.close_shop()


## Rebuild the rows (after every purchase).
func refresh() -> void:
	var w: Wizard = game.player
	_gold.text = "Gold: %d   (+%d this round)" % [Shop.gold_of(game, w), game.round_income(w)]
	for c in _spells_box.get_children():
		c.queue_free()
	for c in _items_box.get_children():
		c.queue_free()
	for c in _new_box.get_children():
		c.queue_free()

	for slot in Shop.SLOTS:
		var s := w.get_spell(slot)
		if s == null:
			continue
		var row := _row()
		row.add_child(_spell_icon(s))
		var lbl := _label("%s  Lv %d/3" % [s.spell_name, s.level], 18)
		lbl.custom_minimum_size.x = 160
		row.add_child(lbl)
		var cost := Shop.upgrade_cost(w, slot)
		var b := _button("Max" if cost < 0 else "Up %dg" % cost, func(): _buy(func(): return Shop.upgrade(game, w, slot)), Vector2(100, 44))
		b.disabled = not Shop.can_upgrade(game, w, slot)
		row.add_child(b)
		if s.spell_id != "" and Shop.SPELLS.has(s.spell_id):
			var id := s.spell_id
			row.add_child(_button("Sell +%dg" % Shop.spell_sell_price(id), func(): _buy(func(): return Shop.sell_spell(game, w, id)), Vector2(100, 44)))
		_spells_box.add_child(row)
	for id in Shop.SPELLS:
		if Shop.has_spell(w, id):
			continue
		var info: Dictionary = Shop.SPELLS[id]
		var row := _row()
		var icon := TextureRect.new()
		var sample: Spell = info.script.new()
		icon.texture = sample.icon
		icon.modulate = sample.icon_tint
		sample.free()
		icon.custom_minimum_size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var lbl := _label("%s\n%s" % [info.name, info.desc], 14)
		lbl.custom_minimum_size.x = 230
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(lbl)
		var full := Shop.free_slot(w, id) == ""
		var b := _button("Full" if full else "Buy %dg" % info.price, func(): _buy(func(): return Shop.buy_spell(game, w, id)), Vector2(90, 44))
		b.disabled = not Shop.can_buy_spell(game, w, id)
		row.add_child(b)
		_new_box.add_child(row)

	_items_title.text = "Items (%d/%d)" % [w.items.size(), Shop.MAX_ITEMS]
	for id in Shop.ITEMS:
		var info: Dictionary = Shop.ITEMS[id]
		var row := _row()
		var icon := ItemIcon.new()
		icon.item = id
		row.add_child(icon)
		var lbl := _label("%s\n%s" % [info.name, info.desc], 15)
		lbl.custom_minimum_size.x = 170
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(lbl)
		var b: Button
		if id in w.items:
			b = _button("Sell +%dg" % Shop.sell_price(id), func(): _buy(func(): return Shop.sell_item(game, w, id)), Vector2(90, 44))
		else:
			b = _button("Buy %dg" % info.price, func(): _buy(func(): return Shop.buy_item(game, w, id)), Vector2(90, 44))
			b.disabled = not Shop.can_buy_item(game, w, id)
		row.add_child(b)
		_items_box.add_child(row)


func _buy(action: Callable) -> void:
	if action.call():
		Sfx.play("coin")
		refresh()


func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	return r


func _spell_icon(s: Spell) -> TextureRect:
	var t := TextureRect.new()
	t.texture = s.icon
	t.modulate = s.icon_tint
	t.custom_minimum_size = Vector2(36, 36)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return t


func _label(text: String, font_size: int, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _button(text: String, cb: Callable, min_size := Vector2(150, 48)) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 18)
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


## Item icons drawn with shapes (no art needed): boot, cloak, ring, gem.
class ItemIcon:
	extends Control

	var item := ""

	func _ready() -> void:
		custom_minimum_size = Vector2(44, 44)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		match item:
			"boots":
				var brown := Color(0.55, 0.32, 0.16)
				draw_rect(Rect2(c.x - 8, c.y - 16, 12, 22), brown)
				draw_rect(Rect2(c.x - 8, c.y + 4, 22, 9), brown)
				draw_rect(Rect2(c.x - 10, c.y - 18, 16, 5), Color(0.75, 0.5, 0.25))
				draw_rect(Rect2(c.x - 8, c.y + 13, 22, 3), Color(0.25, 0.15, 0.08))
			"cloak":
				var grey := Color(0.55, 0.55, 0.6)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -18), c + Vector2(16, 18), c + Vector2(-16, 18)]), grey)
				draw_circle(c + Vector2(0, -10), 7.0, Color(0.42, 0.42, 0.48))
				draw_circle(c + Vector2(0, -9), 4.0, Color(0.12, 0.1, 0.12))
				draw_line(c + Vector2(-6, 0), c + Vector2(6, 0), Color(0.35, 0.35, 0.4), 2.0)
			"ring":
				draw_arc(c + Vector2(0, 4), 12.0, 0, TAU, 32, Color(1.0, 0.78, 0.25), 5.0)
				draw_circle(c + Vector2(0, -9), 6.0, Color(1.0, 0.3, 0.1))
				draw_circle(c + Vector2(-2, -11), 2.0, Color(1, 0.8, 0.6))
			"gem":
				var pts := PackedVector2Array([c + Vector2(0, -18), c + Vector2(14, -4), c + Vector2(0, 18), c + Vector2(-14, -4)])
				draw_colored_polygon(pts, Color(0.3, 0.6, 1.0))
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -18), c + Vector2(14, -4), c + Vector2(0, -4)]), Color(0.65, 0.85, 1.0))
				draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.1, 0.2, 0.5), 2.0)
