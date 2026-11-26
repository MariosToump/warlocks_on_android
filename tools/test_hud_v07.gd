extends SceneTree
## v0.7 HUD tests: off-screen arrows, minimap, damage numbers, haptics,
## danger vignette, pause menu, settings.
##   godot --headless --path . -s tools/test_hud_v07.gd

var game: Node
var arena: Arena
var player: Wizard
var blue: Wizard
var green: Wizard
var c: Vector2
var failures := 0


func _init() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.bot_ai = false
	game.shrink_arena = false
	game.rounds = false
	game.apply_settings = false
	game.title_screen = false
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(5)
	arena = game.arena
	player = game.player
	blue = game.get_node("Wizards/BotBlue")
	green = game.get_node("Wizards/BotGreen")
	c = arena.get_center()
	game.get_node("Wizards/Player/PlayerController").process_mode = Node.PROCESS_MODE_DISABLED
	var cam: ArenaCamera = arena.camera
	player.global_position = c
	cam.global_position = c
	cam.reset_smoothing()
	await _frames(3)

	print("off-screen arrows")
	var view := root.get_visible_rect().size / cam.zoom
	print("  (view %.0f x %.0f world px)" % [view.x, view.y])
	blue.global_position = c + Vector2(0, -view.y * 0.5 - 60.0)
	green.global_position = c + Vector2(view.x * 0.25, 0)
	game.get_node("Wizards/BotPurple").global_position = c + Vector2(-view.x * 0.25, 0)
	await _frames(2)
	var arrows: Array = game.arrows.arrows()
	_check(arrows.size() == 1 and arrows[0].wizard == blue, "one arrow, for the off-screen enemy (%d)" % arrows.size())
	_check(arrows.size() == 1 and arrows[0].dir.y < -0.9, "it points up, toward them")
	green.global_position = c + Vector2(1100, 0)
	await _frames(2)
	arrows = game.arrows.arrows()
	var by := {}
	for a in arrows:
		by[a.wizard] = a
	_check(by.has(green) and by[green].dir.x > 0.9, "far enemy to the right gets a right-pointing arrow")
	_check(by.has(green) and by.has(blue) and by[green].scale < by[blue].scale, "further away = smaller arrow")
	var tip: Vector2 = by[green].tip if by.has(green) else Vector2.ZERO
	_check(absf(tip.x - (root.get_visible_rect().size.x - EnemyArrows.INSET)) < 1.0, "arrow sits on the screen edge (x %.0f)" % tip.x)
	blue.take_damage(500, player)
	await _frames(2)
	arrows = game.arrows.arrows()
	_check(arrows.size() == 1, "no arrow for the dead")
	blue.reset(c + Vector2(0, -400))

	print("minimap")
	var mm: Minimap = game.minimap
	_check(mm.to_map(c).distance_to(mm.size / 2.0) < 0.01, "arena centre = minimap centre")
	var edge := mm.to_map(c + Vector2(arena.platform_radius_tiles * arena.tile_size, 0))
	_check(absf(edge.x - mm.size.x / 2.0 - (Minimap.DIAMETER / 2.0 - 4.0) / 1.15) < 0.5, "platform edge inside the disc (%.1f)" % (edge.x - mm.size.x / 2.0))
	var r := mm.get_global_rect()
	var screen := root.get_visible_rect().size
	_check(absf(r.end.x - (screen.x - 12.0)) < 1.0 and absf(r.position.y - 12.0) < 1.0, "minimap in the top-right corner (%s)" % r)
	var feed_top: float = game.round_hud._feed.get_global_rect().position.y
	_check(feed_top > r.end.y, "kill feed sits below the minimap")

	print("damage numbers")
	await _seconds(1.0)
	var dn: DamageNumbers = game.damage_numbers
	var before := dn.numbers.size()
	green.take_damage(6, player)
	_check(dn.numbers.size() == before + 1 and dn.numbers[-1].text == "6", "a hit shows its damage")
	green.take_damage(2) # lava
	_check(dn.numbers.size() == before + 1, "lava ticks show no number")
	player.take_damage(5, green)
	_check(dn.numbers[-1].color.r > 0.9 and dn.numbers[-1].color.g < 0.5, "hits on you are red")
	await _seconds(1.0)
	_check(dn.numbers.is_empty(), "numbers fade away")

	print("haptics")
	var h: int = game.haptic_count
	player.take_damage(4, green)
	_check(game.haptic_count == h + 1, "buzz when hit")
	player.take_damage(0.1)
	player.take_damage(0.1)
	player.take_damage(0.1)
	_check(game.haptic_count == h + 2, "lava buzzes at most every 0.5 s")
	game.apply_settings = true
	GameSettings.haptics = false
	player.take_damage(4, green)
	_check(game.haptic_count == h + 2, "vibration off in settings = no buzz")
	GameSettings.haptics = true
	game.apply_settings = false
	game.title_screen = false

	print("danger vignette")
	player.reset(c)
	await _seconds(0.6)
	_check(game.vignette.level < 0.01, "hidden in the middle")
	var lava := _first_lava_east()
	player.global_position = lava + Vector2(40, 0)
	await _seconds(0.6)
	_check(game.vignette.level > 0.55, "strong while burning (%.2f)" % game.vignette.level)
	player.global_position = lava - Vector2(25, 0)
	await _seconds(0.8)
	_check(player.alive and not player.on_lava and game.vignette.level > 0.2 and game.vignette.level < 0.5,
			"faint right next to the lava (%.2f)" % game.vignette.level)
	player.reset(c)

	print("sound")
	_check(Sfx.music_name == "music_fight", "fight music playing")
	Sfx.played.clear()
	player.get_spell("Q").cooldown_left = 0.0
	player.cast("Q", player.global_position + Vector2(100, 0))
	await _seconds(0.3)
	_check("fireball" in Sfx.played, "fireball makes a sound")
	player.global_position = _first_lava_east() + Vector2(40, 0)
	await _frames(3)
	_check(Sfx.is_looping("lava"), "lava sizzles while you burn")
	player.reset(c)
	await _seconds(0.2) # on_lava updates on a physics tick
	_check(not Sfx.is_looping("lava"), "and stops when you're out")
	GameSettings.sound = false
	GameSettings.music = false
	Sfx.apply_settings()
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")) and AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")),
			"sound and music settings mute their buses")
	GameSettings.sound = true
	GameSettings.music = true
	Sfx.apply_settings()

	print("pause menu")
	var pm: PauseMenu = game.pause_menu
	game.touch._stick_index = 3
	pm.open()
	_check(paused and pm.is_open(), "pause stops the game")
	_check(game.touch._stick_index == -1, "fingers released on pause")
	var t0: float = player.get_spell("Q").cooldown_left
	player.get_spell("Q").cooldown_left = 1.0
	await _seconds(0.3)
	_check(player.get_spell("Q").cooldown_left == 1.0, "cooldowns frozen while paused")
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not paused and not pm.is_open(), "back button resumes")
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(paused, "back button pauses")
	pm.close()
	player.get_spell("Q").cooldown_left = t0

	print("settings")
	var keep_path := GameSettings.path
	GameSettings.path = "user://test_settings.cfg"
	GameSettings.zoom = "far"
	GameSettings.difficulty = 2
	GameSettings.wins_to_take_match = 3
	GameSettings.haptics = false
	GameSettings.save_settings()
	GameSettings.reset()
	GameSettings.load_settings()
	_check(GameSettings.zoom == "far" and GameSettings.difficulty == 2 and GameSettings.wins_to_take_match == 3
			and not GameSettings.haptics, "settings survive save + load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.path))
	GameSettings.path = keep_path
	var ai := AIController.new()
	ai.name = "AIController"
	ai.profile = game.PROFILES[0]
	ai.process_mode = Node.PROCESS_MODE_DISABLED
	blue.add_child(ai)
	var z_before: float = cam.zoom.x
	game.apply_live_settings()
	_check(ai.profile == game.PROFILES[2], "bot difficulty applies at once")
	# (Headless has a 64 px viewport, so check the wanted zoom, not the snapped one.)
	_check(game.follow_zoom == GameSettings.ZOOMS.far and cam.zoom.x <= z_before,
			"zoom 'far' zooms out (follow_zoom %.2f)" % game.follow_zoom)
	pm._refresh()
	_check(pm._wins.text.ends_with("(next match)"), "wins change waits for the next match ('%s')" % pm._wins.text)
	game.apply_settings = true
	game.start_match()
	_check(game.wins_to_take_match == 3, "new match uses the new wins setting")
	GameSettings.reset()

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


## First lava point walking east from the centre.
func _first_lava_east() -> Vector2:
	var p := c
	while not arena.is_lava_at(p):
		p.x += 4.0
	return p


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(s: float) -> void:
	await create_timer(s, true).timeout
