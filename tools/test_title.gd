extends SceneTree
## Title menu tests: bots brawl behind it with the player parked, Play
## starts a match, Settings opens without pausing, Quit to menu and the
## match-over Menu button come back to it.
##   godot --headless --path . -s tools/test_title.gd

var game: Node
var player: Wizard
var failures := 0
var casts := 0


func _init() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.apply_settings = false
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(3)
	player = game.player
	for w in game.all_wizards:
		w.cast_started.connect(func(_s): casts += 1)

	print("title screen")
	_check(game.state == game.State.TITLE and game.title_menu.visible, "starts on the title menu")
	_check(not player.visible and not player.is_in_group("wizards") and player.collision_layer == 0, "player parked out of the fight")
	_check(not game.round_hud.visible and not game.minimap.visible and not game.touch.visible, "match HUD and touch controls hidden")
	_check(Sfx.music_name == "music_title", "title music")
	await _seconds(4.0)
	_check(casts > 0, "bots fight behind the menu (%d casts)" % casts)
	var cam_target = game.arena.camera.target
	_check(cam_target is Wizard and cam_target != player, "camera follows a bot")
	_check(player.health == player.max_health, "nobody can hit the parked player")

	print("settings from the title")
	game.pause_menu.open_settings()
	_check(game.pause_menu.is_open() and not paused, "settings open, fight keeps going")
	_check(not game.pause_menu._restart_button.visible and game.pause_menu._resume.text == "Back", "settings only (Back, no Restart)")
	game.pause_menu.close()
	_check(not game.pause_menu.is_open() and not game.pause_menu._pause_button.visible, "closed; no pause button on the title")

	print("play")
	game.title_menu._play.pressed.emit()
	await _frames(2)
	_check(game.state == game.State.COUNTDOWN and game.round_number == 1, "Play starts round 1")
	_check(player.visible and player.is_in_group("wizards") and player.collision_layer != 0, "player back in the game")
	_check(not game.title_menu.visible and game.round_hud.visible and game.minimap.visible and game.touch.visible, "match HUD and touch controls shown")
	_check(game.pause_menu._pause_button.visible, "pause button back")
	_check(Sfx.music_name == "music_fight", "fight music")

	print("quit to menu")
	await _seconds(3.2)
	game.pause_menu.open()
	_check(paused, "paused")
	game.pause_menu._quit.pressed.emit()
	await _frames(2)
	_check(game.state == game.State.TITLE and not paused and game.title_menu.visible, "Quit to menu -> title, unpaused")
	_check(not player.visible and not player.is_in_group("wizards"), "player parked again")

	print("match over -> Menu")
	game.start_from_title()
	await _frames(2)
	game.state = game.State.MATCH_OVER
	game.round_hud.menu_pressed.emit()
	await _frames(2)
	_check(game.state == game.State.TITLE, "Menu on the results screen -> title")

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(s: float) -> void:
	await create_timer(s, true).timeout
