extends SceneTree
## Game feel (v0.9): screen shake, hit-stop, knockback streak.
##   godot --headless --path . -s tools/test_feel.gd

var game: Node
var failures := 0


func _init() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.bot_ai = false
	game.rounds = false
	game.apply_settings = false
	game.title_screen = false
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(3)
	var cam: ArenaCamera = game.arena.camera
	var player: Wizard = game.player
	var blue: Wizard = game.get_node("Wizards/BotBlue")
	player.get_node("PlayerController").process_mode = Node.PROCESS_MODE_DISABLED

	print("shake")
	cam.shake(6.0, 0.3)
	await process_frame
	await process_frame
	_check(cam.shaking() and cam.offset != Vector2.ZERO and cam.offset.length() <= 6.0 * 1.5, "shake moves the view (%s)" % cam.offset)
	cam.shake(1.0, 0.3)
	_check(cam._shake == 6.0, "a weak shake doesn't cut a strong one short")
	await _seconds(0.4)
	_check(not cam.shaking() and cam.offset == Vector2.ZERO, "and settles back to zero")
	player.take_damage(8.0, blue)
	await process_frame
	_check(cam.shaking(), "the player getting hit shakes the screen")
	await _seconds(0.4)

	print("hit-stop")
	game.hit_stop(0.05)
	_check(Engine.time_scale < 0.2, "time slows (%.2f)" % Engine.time_scale)
	game.hit_stop(0.05) # overlapping
	await _seconds_real(0.12)
	_check(Engine.time_scale == 1.0, "and comes back to 1 (%.2f)" % Engine.time_scale)
	player.take_damage(12.0, blue)
	_check(Engine.time_scale < 0.2, "a big hit on the player freezes a moment")
	await _seconds_real(0.12)
	_check(Engine.time_scale == 1.0, "back to normal after it")

	print("knockback streak")
	blue.global_position = game.arena.get_center()
	blue.knockback = Vector2.ZERO
	await _frames(3)
	_check(not blue.has_trail(), "no streak standing still")
	blue.apply_knockback(Vector2(700, 0))
	await _frames(4)
	_check(blue.has_trail(), "a streak while flying fast")
	await _seconds(1.5)
	_check(not blue.has_trail(), "gone once it slows down")

	print("reduce screen shake")
	await create_timer(0.5).timeout
	GameSettings.reduce_shake = true
	cam.shake(6.0, 0.3)
	var peak := 0.0
	for i in 6:
		await process_frame
		peak = maxf(peak, cam.offset.length())
	_check(peak <= 6.0 * Feel.REDUCED_SHAKE_SCALE * 1.5, "reduced shake stays small (%.1f px)" % peak)
	GameSettings.reduce_shake = false
	var pm = game.get_node_or_null("HUD/PauseMenu")
	if pm:
		pm._refresh()
		_check(pm._shake.text.begins_with("Screen shake"), "pause menu has the shake option")

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
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


func _seconds_real(s: float) -> void:
	await create_timer(s, true, false, true).timeout
