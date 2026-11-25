class_name TitleMenu
extends Control
## Title screen, drawn over a live bots-only fight (game.State.TITLE):
## game name, Play, Settings, version.

var game: Node

var _play: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH

	var title := Label.new()
	title.text = "WARLOCKS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.2))
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.03, 0.0))
	title.add_theme_constant_override("outline_size", 16)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Knock them into the lava. Last one standing wins."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_outline_color", Color.BLACK)
	sub.add_theme_constant_override("outline_size", 6)
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	box.add_child(gap)
	_play = _button(box, "Play", _on_play)
	_play.add_theme_font_size_override("font_size", 34)
	_play.custom_minimum_size = Vector2(320, 76)
	_button(box, "Settings", _on_settings)

	var version := Label.new()
	version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "")
	version.add_theme_font_size_override("font_size", 16)
	version.modulate = Color(1, 1, 1, 0.6)
	add_child(version)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -120
	version.offset_top = -34
	version.offset_right = -14
	version.offset_bottom = -10
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 26)
	b.custom_minimum_size = Vector2(320, 60)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _on_play() -> void:
	Sfx.play("click")
	game.start_from_title()


func _on_settings() -> void:
	game.pause_menu.open_settings()
