extends SceneTree
## PC build (2026-11-28): no touch layer, keyboard + mouse, the WC3-style bar.
##   godot --path . -s tools/test_pc.gd   (windowed: the bar layout needs a window)

var game: Node
var player: Wizard
var failures := 0


func _init() -> void:
	Platform.forced = Platform.Mode.PC
	game = load("res://scenes/game.tscn").instantiate()
	game.bot_ai = false
	game.apply_settings = false
	game.title_screen = false
	game.shrink_arena = false
	game.countdown_time = 0.3
	game.round_over_time = 0.3
	game.shop_time = 0.02
	game.spectate_delay = 0.3
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(3)
	player = game.player
	print("PC mode")
	_check(game.touch_mode == false, "touch_mode off")
	_check(game.touch.enabled == false, "touch layer disabled")
	_check(game.touch.visible == false, "touch layer hidden")
	_check(Input.emulate_touch_from_mouse == false, "mouse does not emulate touch")
	await _seconds(1.0)
	_check(game.touch.visible == false, "touch layer still hidden in the round")
	await _test_keys()
	await _test_settings_rows()
	await _test_ghost()
	_finish()


func _key(code: Key, alt := false) -> void:
	for down in [true, false]:
		var k := InputEventKey.new()
		k.keycode = code
		k.physical_keycode = code
		k.alt_pressed = alt
		k.pressed = down
		Input.parse_input_event(k)
	await process_frame
	await process_frame


func _test_keys() -> void:
	print("Esc and Alt+Enter")
	GameSettings.path = "user://test_pc_settings.cfg"
	var pm: PauseMenu = game.pause_menu
	await _key(KEY_ESCAPE)
	_check(pm.is_open() and paused, "Esc pauses")
	await _key(KEY_ESCAPE)
	_check(not pm.is_open() and not paused, "Esc again resumes")
	var fs := GameSettings.fullscreen
	await _key(KEY_ENTER, true)
	_check(GameSettings.fullscreen != fs, "Alt+Enter flips fullscreen")
	await _key(KEY_ENTER, true)
	_check(GameSettings.fullscreen == fs, "Alt+Enter flips it back")
	game.open_shop()
	await _frames(2)
	await _key(KEY_ESCAPE)
	_check(pm.is_open(), "Esc during the shop opens the pause menu")
	await _key(KEY_ESCAPE)
	game.close_shop()
	await _frames(2)


func _test_settings_rows() -> void:
	print("settings rows on PC")
	var texts := {}
	for b in game.pause_menu.find_children("*", "Button", true, false):
		texts[(b as Button).text.get_slice(":", 0)] = (b as Button).visible
	_check(texts.get("Fullscreen", false), "Fullscreen row shown")
	_check(texts.has("Vibration") and not texts["Vibration"], "Vibration row hidden")
	_check(texts.has("Move") and not texts["Move"], "Move row hidden")


func _test_ghost() -> void:
	print("ghost on PC")
	await _until(func(): return game.state == game.State.FIGHT, 5.0)
	player.take_damage(999, null)
	await _until(func(): return game.ghost != null, 3.0)
	var ctl: PlayerController = player.get_node("PlayerController")
	_check(game.ghost != null and ctl.ghost == game.ghost, "the controller has the ghost")
	if game.ghost == null:
		return
	var a := InputEventAction.new()
	a.action = "attack"
	a.pressed = true
	Input.parse_input_event(a)
	await process_frame
	await process_frame
	_check(game.ghost.haunt_left > 0.0, "A haunts")
	var c: Vector2 = game.arena.get_center()
	game.ghost.global_position = c + Vector2(300, 0)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	# Events are in window pixels; the HUD is in 1280x720 viewport pixels.
	mb.position = root.get_final_transform() * game.minimap.get_global_rect().get_center()
	Input.parse_input_event(mb)
	await process_frame
	await process_frame
	_check(game.ghost.global_position.distance_to(c) < 40.0,
			"minimap click teleports (%.0f px from the centre)" % game.ghost.global_position.distance_to(c))
	await _frames(2)
	_check(player.move_dir == Vector2.ZERO, "no right mouse: the ghost stays still")


func _until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while not cond.call() and t < limit:
		await physics_frame
		t += 1.0 / 60.0


func _finish() -> void:
	print("TEST PASSED" if failures == 0 else "TEST FAILED (%d)" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(s: float) -> void:
	await create_timer(s).timeout
