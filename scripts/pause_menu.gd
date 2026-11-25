class_name PauseMenu
extends Control
## Pause button (top right, left of the minimap) and the pause panel:
## Resume, Restart match, and settings (zoom, bot difficulty, wins per match,
## vibration). The Android back button toggles it too (game.gd).
## Runs while the tree is paused.

const BUTTON_SIZE := Vector2(64, 64)

var game: Node

var _pause_button: Button
var _panel: PanelContainer
var _zoom: Button
var _bots: Button
var _wins: Button
var _haptics: Button
var _sound: Button
var _music: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_pause_button = Button.new()
	_pause_button.text = "II"
	_pause_button.add_theme_font_size_override("font_size", 26)
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.pressed.connect(open)
	add_child(_pause_button)
	_pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	# Left of the 150 px minimap in the corner.
	_pause_button.offset_right = -12.0 - Minimap.DIAMETER - 10.0
	_pause_button.offset_left = _pause_button.offset_right - BUTTON_SIZE.x
	_pause_button.offset_top = 12.0
	_pause_button.offset_bottom = 12.0 + BUTTON_SIZE.y

	_build_panel()


func _build_panel() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.name = "Dim"
	add_child(dim)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.05, 0.94)
	sb.border_color = Color(1.0, 0.45, 0.15)
	sb.set_border_width_all(3)
	sb.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", sb)
	dim.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)
	_button(box, "Resume", close)
	_button(box, "Restart match", _restart)
	var sep := HSeparator.new()
	box.add_child(sep)
	_zoom = _button(box, "", _cycle_zoom)
	_bots = _button(box, "", _cycle_bots)
	_wins = _button(box, "", _cycle_wins)
	_haptics = _button(box, "", _toggle_haptics)
	_sound = _button(box, "", _toggle_sound)
	_music = _button(box, "", _toggle_music)
	_refresh()
	dim.visible = false


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 24)
	b.custom_minimum_size = Vector2(380, 58)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func is_open() -> bool:
	return get_node("Dim").visible


func open() -> void:
	if is_open():
		return
	game.touch.release_all()
	Sfx.loop("lava", false)
	Sfx.play("click")
	get_tree().paused = true
	get_node("Dim").visible = true
	_pause_button.visible = false
	_refresh()


func close() -> void:
	get_tree().paused = false
	get_node("Dim").visible = false
	_pause_button.visible = true


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func _restart() -> void:
	close()
	game.start_match()


func _refresh() -> void:
	_zoom.text = "Zoom: %s" % GameSettings.zoom.capitalize()
	_bots.text = "Bots: %s" % ["Easy", "Normal", "Hard"][GameSettings.difficulty]
	var wins_text := "First to %d wins" % GameSettings.wins_to_take_match
	if game and GameSettings.wins_to_take_match != game.wins_to_take_match:
		wins_text += " (next match)"
	_wins.text = wins_text
	_haptics.text = "Vibration: %s" % ("On" if GameSettings.haptics else "Off")
	_sound.text = "Sound: %s" % ("On" if GameSettings.sound else "Off")
	_music.text = "Music: %s" % ("On" if GameSettings.music else "Off")


func _cycle_zoom() -> void:
	GameSettings.zoom = "far" if GameSettings.zoom == "close" else "close"
	_changed()


func _cycle_bots() -> void:
	GameSettings.difficulty = (GameSettings.difficulty + 1) % 3
	_changed()


func _cycle_wins() -> void:
	var i := GameSettings.WINS.find(GameSettings.wins_to_take_match)
	GameSettings.wins_to_take_match = GameSettings.WINS[(i + 1) % GameSettings.WINS.size()]
	_changed()


func _toggle_haptics() -> void:
	GameSettings.haptics = not GameSettings.haptics
	_changed()


func _toggle_sound() -> void:
	GameSettings.sound = not GameSettings.sound
	_changed()


func _toggle_music() -> void:
	GameSettings.music = not GameSettings.music
	_changed()


func _changed() -> void:
	Sfx.play("click")
	GameSettings.save_settings()
	game.apply_live_settings()
	_refresh()
