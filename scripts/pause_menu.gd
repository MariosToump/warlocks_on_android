class_name PauseMenu
extends Control
## Pause button (top right, left of the minimap) and the pause panel:
## Resume, Restart match, and settings (zoom, bot difficulty, wins per match,
## vibration). The Android back button toggles it too (game.gd).
## PC: Esc toggles it, Alt+Enter toggles fullscreen; Settings shows
## Fullscreen instead of Vibration and Move.
## Runs while the tree is paused.

const BUTTON_SIZE := Vector2(64, 64)

var game: Node

var _pause_button: Button
var _panel: PanelContainer
var _zoom: Button
var _bots: Button
var _wins: Button
var _haptics: Button
var _haze: Button
var _shake: Button
var _move: Button
var _sound: Button
var _music: Button
var _fullscreen: Button
var _title: Label
var _resume: Button
var _restart_button: Button
var _quit: Button
## Opened from the title menu: settings only, no pausing the bots' fight.
var _settings_only := false


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
	_title = Label.new()
	_title.text = "Paused"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 36)
	box.add_child(_title)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(actions)
	_resume = _button(actions, "Resume", close, 250)
	_restart_button = _button(actions, "Restart match", _restart, 250)
	_quit = _button(actions, "Quit to menu", _quit_to_menu, 250)
	var sep := HSeparator.new()
	box.add_child(sep)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	_zoom = _button(grid, "", _cycle_zoom)
	_bots = _button(grid, "", _cycle_bots)
	_wins = _button(grid, "", _cycle_wins)
	_haptics = _button(grid, "", _toggle_haptics)
	_sound = _button(grid, "", _toggle_sound)
	_music = _button(grid, "", _toggle_music)
	_move = _button(grid, "", _cycle_move)
	_haze = _button(grid, "", _toggle_heat_haze)
	_shake = _button(grid, "", _toggle_reduce_shake)
	_fullscreen = _button(grid, "", _toggle_fullscreen)
	var touch := Platform.touch()
	_fullscreen.visible = not touch
	_haptics.visible = touch
	_move.visible = touch
	_refresh()
	dim.visible = false


func _button(parent: Node, text: String, cb: Callable, width := 380) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 24)
	b.custom_minimum_size = Vector2(width, 58)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func is_open() -> bool:
	return get_node("Dim").visible


func open() -> void:
	if is_open():
		return
	_settings_only = false
	_title.text = "Paused"
	_resume.text = "Resume"
	_restart_button.visible = true
	_quit.visible = true
	game.touch.release_all()
	Sfx.loop("lava", false)
	Sfx.play("click")
	get_tree().paused = true
	get_node("Dim").visible = true
	_pause_button.visible = false
	_refresh()


## From the title menu: just the settings and a Back button; the bots keep
## fighting behind it.
func open_settings() -> void:
	_settings_only = true
	_title.text = "Settings"
	_resume.text = "Back"
	_restart_button.visible = false
	_quit.visible = false
	Sfx.play("click")
	get_node("Dim").visible = true
	_refresh()


func close() -> void:
	if not _settings_only:
		get_tree().paused = false
	_settings_only = false
	get_node("Dim").visible = false
	set_pause_button(game.state != game.State.TITLE)


func set_pause_button(on: bool) -> void:
	_pause_button.visible = on and not is_open()


func _quit_to_menu() -> void:
	close()
	game.enter_title()


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
	_move.text = "Move: %s" % GameSettings.move_mode.capitalize()
	_haze.text = "Heat shimmer: %s" % ("On" if GameSettings.heat_haze else "Off")
	_fullscreen.text = "Fullscreen: %s" % ("On" if GameSettings.fullscreen else "Off")
	_shake.text = "Screen shake: %s" % ("Reduced" if GameSettings.reduce_shake else "Full")


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


func _cycle_move() -> void:
	GameSettings.move_mode = "touchpad" if GameSettings.move_mode == "joystick" else "joystick"
	_changed()


func _toggle_haptics() -> void:
	GameSettings.haptics = not GameSettings.haptics
	_changed()


func _toggle_heat_haze() -> void:
	GameSettings.heat_haze = not GameSettings.heat_haze
	_changed()


func _toggle_fullscreen() -> void:
	GameSettings.fullscreen = not GameSettings.fullscreen
	GameSettings.apply_window()
	_changed()


## PC keys (this node runs while paused): Esc = pause / resume (on the
## title it only closes the settings), Alt+Enter = fullscreen.
func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.alt_pressed and k.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_toggle_fullscreen()
		return
	if event.is_action_pressed("pause") and game:
		get_viewport().set_input_as_handled()
		if game.state == game.State.TITLE:
			if is_open():
				close()
		else:
			toggle()


func _toggle_reduce_shake() -> void:
	GameSettings.reduce_shake = not GameSettings.reduce_shake
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
