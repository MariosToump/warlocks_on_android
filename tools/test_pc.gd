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
	await _test_bar()
	await _test_smart_cast()
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
	_check(texts.has("Zoom") and not texts["Zoom"], "Zoom row hidden (the wheel zooms)")


func _test_bar() -> void:
	print("WC3-style bar")
	var bar: PcBar = game.pc_bar
	_check(bar != null, "the bar exists on PC")
	if bar == null:
		return
	_check(bar.shown("Q") and bar.shown("A") and not bar.shown("D"), "Q and A shown, empty D not")
	var q := bar.slot_rect("Q")
	var w := bar.slot_rect("W")
	_check(q.position.x < w.position.x and is_equal_approx(q.position.y, w.position.y), "Q left of W, same row")
	_check(is_equal_approx(bar.card_rect().end.x, bar.size.x - PcBar.PAD), "card at the right edge")
	var mm: Rect2 = game.minimap.get_global_rect()
	_check(mm.position.x < 20.0 and bar.map_frame_rect().encloses(mm), "minimap in the bottom-left frame")
	_check(bar.blocks_mouse(Vector2(640, bar.size.y - 5)), "the bar blocks the mouse at the bottom")
	_check(is_equal_approx(bar.strip_rect().size.y, 84.0) and is_equal_approx(bar.slot_rect("Q").size.x, 44.0),
			"smaller bar: strip 84, icons 44")
	_check(is_equal_approx(game.minimap.size.x, 110.0), "smaller minimap: 110 (%.0f)" % game.minimap.size.x)
	var cam: ArenaCamera = game.arena.camera
	var far_out := maxf(roundf(cam.min_zoom * cam.screen_scale()), 1.0) / cam.screen_scale()
	_check(is_equal_approx(cam.zoom.x, far_out), "starts zoomed out (zoom %.2f, furthest %.2f)" % [cam.zoom.x, far_out])
	_check(not bar.blocks_mouse(Vector2(640, 300)), "but not mid-screen")
	_check(bar.tooltip_text("Q").begins_with("Fireball") and "Cooldown" in bar.tooltip_text("Q"),
			"Q tooltip: " + bar.tooltip_text("Q").replace("
", " | "))
	game.gold[player] = 100
	Shop.buy_spell(game, player, "homing")
	_check(bar.shown("D"), "a bought spell shows in D")
	_check("curves" in bar.tooltip_text("D"), "D tooltip uses the shop text")
	await _until(func(): return game.state == game.State.FIGHT, 5.0)
	player.cast("Q", player.global_position + Vector2(100, 0))
	await _seconds(0.5)
	_check(player.get_spell("Q").cooldown_ratio() > 0.0, "Q cooling down after a cast")
	var old := root.size
	root.size = Vector2i(1600, 720)
	await process_frame
	await process_frame
	_check(is_equal_approx(bar.card_rect().end.x, bar.size.x - PcBar.PAD), "after a resize the card stays at the right edge")
	root.size = old
	await process_frame


func _action(action: String, down: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = down
	Input.parse_input_event(e)
	await process_frame
	await process_frame


func _ready_all() -> void:
	await _until(func(): return not player.is_casting(), 2.0)
	for sp in player.get_node("Spells").get_children():
		(sp as Spell).cooldown_left = 0.0


func _test_smart_cast() -> void:
	print("smart cast")
	var ctl: PlayerController = player.get_node("PlayerController")
	await _until(func(): return game.state == game.State.FIGHT, 5.0)
	await _ready_all()
	var q := player.get_spell("Q")
	await _action("spell_q", true)
	_check(ctl.aiming_slot == "Q" and ctl._indicator.visible, "holding Q shows the indicator")
	_check(q.cooldown_left == 0.0, "holding Q doesn't cast yet")
	await _action("spell_q", false)
	_check(q.cooldown_left > 0.0, "releasing Q casts")
	_check(ctl.aiming_slot == "" and not ctl._indicator.visible, "the indicator goes away")
	await _ready_all()
	player.move_target = null
	await _action("spell_w", true)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_RIGHT
	mb.pressed = true
	mb.position = root.get_final_transform() * Vector2(640, 300)
	Input.parse_input_event(mb)
	await process_frame
	await process_frame
	_check(ctl.aiming_slot == "" and player.move_target == null, "right-click cancels, no walk")
	await _action("spell_w", false)
	_check(player.get_spell("W").cooldown_left == 0.0, "a cancelled Blink isn't cast")
	mb.pressed = false
	Input.parse_input_event(mb)
	await _ready_all()
	await _action("spell_r", true)
	_check(player.get_spell("R").cooldown_left > 0.0, "Shield casts on key down")
	await _action("spell_r", false)
	await _ready_all()
	GameSettings.cast_mode = "instant"
	await _action("spell_q", true)
	_check(q.cooldown_left > 0.0, "instant mode: Q casts on key down")
	await _action("spell_q", false)
	GameSettings.cast_mode = "indicator"
	await _ready_all()
	await _action("spell_q", true)
	game.pause_menu.open()
	await process_frame
	_check(ctl.aiming_slot == "", "pausing drops the aim")
	game.pause_menu.close()
	await _action("spell_q", false)
	_check(q.cooldown_left == 0.0, "a key released while paused doesn't cast")


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
	_check(game.pc_bar.shown("A") and not game.pc_bar.shown("Q"), "ghost: only A on the bar")
	_check(game.pc_bar.tooltip_text("A").begins_with("Haunt"), "ghost: A is Haunt")
	await _action("spell_q", true)
	_check(ctl.aiming_slot == "" and not ctl._indicator.visible, "ghost: a spell key shows no indicator")
	await _action("spell_q", false)


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
