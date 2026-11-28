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
	_finish()


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
