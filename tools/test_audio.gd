extends SceneTree
## Audio fixes (2026-11-27): the bus effects, the voice limits, and that the
## new feedback sounds fire on their events. Headless has no audio out, so
## event sounds are checked through Sfx.played.
##   godot --headless --path . -s tools/test_audio.gd

var failures := 0
var game: Node


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
	# --- files and buses ---------------------------------------------------
	var missing := []
	for n in Sfx.SOUNDS:
		var s: AudioStream = Sfx.SOUNDS[n]
		if s == null or s.get_length() <= 0.0:
			missing.append(n)
	_check(missing.is_empty(), "all %d sounds load (%s)" % [Sfx.SOUNDS.size(), missing])
	for n in ["reflect", "kill", "lava_warn", "heartbeat", "match_win", "match_lose", "denied", "rockwall",
			"boomerang_return", "ghost", "homing_hum"]:
		_check(Sfx.SOUNDS.has(n), "new sound '%s'" % n)
	_check((Sfx.SOUNDS["lava"] as AudioStreamWAV).get_length() >= 6.0, "lava loop is 6 s or more")
	var master := AudioServer.get_bus_index(&"Master")
	var lim: AudioEffect = AudioServer.get_bus_effect(master, 0) if AudioServer.get_bus_effect_count(master) > 0 else null
	_check(lim is AudioEffectHardLimiter and AudioServer.is_bus_effect_enabled(master, 0), "Master has a hard limiter")
	_check(lim is AudioEffectHardLimiter and is_equal_approx((lim as AudioEffectHardLimiter).ceiling_db, -1.0), "limiter ceiling -1 dB")
	_check(not Sfx.is_music_muffled(), "music not muffled in a fight")
	Sfx.muffle_music(true)
	_check(Sfx.is_music_muffled(), "muffle_music(true) turns on the Music low-pass")
	Sfx.muffle_music(false)
	_check(not Sfx.is_music_muffled(), "muffle_music(false) turns it off")

	# --- voice picking (own voices: headless Sfx keeps none) --------------
	var voices: Array[AudioStreamPlayer] = []
	var prio: Array[bool] = []
	for i in 4:
		var p := AudioStreamPlayer.new()
		root.add_child(p)
		voices.append(p)
		prio.append(false)
	Sfx._voices = voices
	Sfx._prio = prio
	_check(Sfx.pick_voice("hit", false) == 0, "a free voice is used first")
	for i in 3:
		voices[i].stream = Sfx.SOUNDS["hit"]
		voices[i].play()
	await _frames(2)
	var any_playing := voices[0].playing
	if any_playing:
		_check(Sfx.pick_voice("hit", false) == -1, "a 4th 'hit' at once is skipped")
		_check(Sfx.pick_voice("death", true) == 3, "a priority sound still gets the free voice")
		voices[3].stream = Sfx.SOUNDS["death"]
		voices[3].play()
		prio[3] = true
		await _frames(1)
		var v := Sfx.pick_voice("fireball", false)
		_check(v >= 0 and v != 3, "a normal sound never steals a priority voice (got %d)" % v)
	else:
		print("  skip voice-steal checks (this audio driver doesn't play)")
	for p in voices:
		p.stop()
		p.queue_free()
	Sfx._voices.clear()
	Sfx._prio.clear()

	# --- events ------------------------------------------------------------
	var player: Wizard = game.get_node("Wizards/Player")
	var blue: Wizard = game.get_node("Wizards/BotBlue")
	# Shield reflect.
	Sfx.played.clear()
	var c: Vector2 = game.get_node("Arena").get_center()
	player.global_position = c + Vector2(-200, 0)
	blue.global_position = c + Vector2(100, 0)
	await _frames(2)
	blue.cast("R", blue.global_position)
	await _frames(2)
	player.cast("Q", blue.global_position)
	var t0 := Time.get_ticks_msec()
	while not "reflect" in Sfx.played and Time.get_ticks_msec() - t0 < 2000:
		await _frames(1)
	_check("reflect" in Sfx.played, "a shield reflect plays 'reflect'")
	# Kill credit for the player.
	Sfx.played.clear()
	game.state = game.State.FIGHT
	blue.last_attacker = player
	blue.last_hit_at = GameClock.now()
	game._on_wizard_died(blue)
	_check("kill" in Sfx.played, "the player's kill plays 'kill'")
	# Low health heartbeat.
	Sfx.played.clear()
	player.health = player.max_health * 0.2
	game._feel_heartbeat(0.016)
	_check("heartbeat" in Sfx.played, "under 25% health plays a heartbeat")
	Sfx.played.clear()
	game._feel_heartbeat(0.3)
	_check(not "heartbeat" in Sfx.played, "the heartbeat is slow (not every frame)")
	player.health = player.max_health
	# Denied in the shop.
	Sfx.played.clear()
	game.shop_panel._buy(func(): return false)
	_check("denied" in Sfx.played, "a failed buy plays 'denied'")
	Sfx.played.clear()
	game.shop_panel._buy(func(): return true)
	_check("coin" in Sfx.played and not "denied" in Sfx.played, "a good buy plays 'coin'")
	game.state = game.State.FREE

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame
