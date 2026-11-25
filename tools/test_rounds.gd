extends SceneTree
## Rounds, score and match tests (milestone 6). Bots are passive dummies.
##   godot --headless --path . -s tools/test_rounds.gd

var game: Node
var arena: Arena
var player: Wizard
var blue: Wizard
var green: Wizard
var purple: Wizard
var failures := 0


func _init() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.bot_ai = false
	game.apply_settings = false
	game.shrink_arena = false
	game.countdown_time = 0.5
	game.round_over_time = 0.4
	game.shop_time = 0.02 # shop tested in test_shop.gd
	game.spectate_delay = 0.2
	game.wins_to_take_match = 2
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(3)
	arena = game.get_node("Arena")
	player = game.player
	blue = game.get_node("Wizards/BotBlue")
	green = game.get_node("Wizards/BotGreen")
	purple = game.get_node("Wizards/BotPurple")
	var pc := player.get_node("PlayerController")
	var c := arena.get_center()

	print("round 1 countdown")
	_check(game.state == game.State.COUNTDOWN and game.round_number == 1, "starts in round 1's countdown")
	_check(pc.process_mode == Node.PROCESS_MODE_DISABLED, "player can't act during the countdown")
	_check(game.touch.locked, "touch controls locked during the countdown")
	var ring_ok := true
	for w in game.all_wizards:
		var d: Vector2 = (w.global_position - c) / Vector2(1.0, 0.5)
		ring_ok = ring_ok and absf(d.length() - game.spawn_distance) < 2.0
	_check(ring_ok, "everyone starts on the spawn ellipse")
	var hud: RoundHud = game.round_hud
	_check(hud._banner.text == "Round 1", "banner says 'Round 1' ('%s')" % hud._banner.text)

	await _seconds(0.6)
	_check(game.state == game.State.FIGHT, "fight starts after the countdown")
	_check(pc.process_mode == Node.PROCESS_MODE_INHERIT, "player can act in the fight")
	_check(not game.touch.locked, "touch controls unlocked in the fight")

	print("kills and the last wizard standing")
	blue.take_damage(500, player)
	await _frames(2)
	_check(game.kills[player] == 1, "killing blow scores a kill")
	_check(game.state == game.State.FIGHT, "round goes on while 3 are alive")
	green.take_damage(500) # lava, nobody to blame
	await _frames(2)
	_check(game.kills[player] == 1, "a death with no attacker scores no kill")
	purple.take_damage(500, green) # green is dead but hit last: still credited
	await _frames(2)
	_check(game.state == game.State.ROUND_OVER, "round ends when one is left")
	_check(game.round_winner == player and game.wins[player] == 1, "survivor wins the round")
	_check(hud._banner.text == "You win the round!", "banner names the winner ('%s')" % hud._banner.text)
	_check(pc.process_mode == Node.PROCESS_MODE_DISABLED, "controls off after the round")
	_check(game.touch.locked, "touch controls locked after the round")

	print("next round resets everything")
	var junk := Node2D.new()
	game.wizards.add_child(junk) # stands in for a leftover projectile
	player.take_damage(30)
	player.get_spell("Q").cooldown_left = 5.0
	await _seconds(0.5)
	_check(game.state == game.State.COUNTDOWN and game.round_number == 2, "round 2 starts")
	var all_back := true
	for w in game.all_wizards:
		all_back = all_back and w.alive and is_equal_approx(w.health, w.max_health)
	_check(all_back, "everyone alive with full health")
	_check(not is_instance_valid(junk) or junk.is_queued_for_deletion(), "leftover projectiles cleared")
	_check(player.get_spell("Q").cooldown_left == 0.0, "cooldowns reset")
	_check(arena.radius_tiles == arena.platform_radius_tiles, "platform back to full size")
	_check(game.wins[player] == 1 and game.kills[player] == 1, "score kept between rounds")

	print("draw")
	await _seconds(0.6)
	for w in game.all_wizards:
		w.take_damage(500)
	await _frames(2)
	_check(game.state == game.State.ROUND_OVER and game.round_winner == null, "all dead on one tick = draw")
	_check(game.wins[player] == 1, "nobody scores on a draw")
	_check(hud._banner.text == "Draw!", "banner says draw")

	print("spectate, then win the match")
	await _seconds(0.5)
	await _seconds(0.6) # round 3 fight
	_check(game.state == game.State.FIGHT and game.round_number == 3, "round 3 fight")
	player.take_damage(500, purple)
	await _seconds(0.4)
	_check(arena.camera.target == purple, "camera follows the player's killer")
	blue.take_damage(500, purple)
	green.take_damage(500, purple)
	await _frames(2)
	_check(game.round_winner == purple and game.match_winner == null, "purple wins round 3 (1 / 2)")
	await _seconds(0.5)
	await _seconds(0.6)
	for w in [player, blue, green]:
		w.take_damage(500, purple)
	await _frames(2)
	_check(game.match_winner == purple, "second win takes the match")
	await _seconds(0.5)
	_check(game.state == game.State.MATCH_OVER, "match over screen")
	_check(hud._match_panel.visible, "match panel shown")
	_check(hud._standings.text.begins_with("1.  Purple"), "winner listed first:\n%s" % hud._standings.text)

	print("play again")
	hud._play_again.pressed.emit()
	await _frames(2)
	_check(game.state == game.State.COUNTDOWN and game.round_number == 1, "new match from round 1")
	var zero := true
	for w in game.all_wizards:
		zero = zero and game.wins[w] == 0 and game.kills[w] == 0
	_check(zero, "scores back to zero")
	_check(not hud._match_panel.visible, "panel hidden")
	_check(arena.camera.target == null, "countdown camera shows the whole field")
	await _seconds(0.6)
	_check(arena.camera.target == player, "camera back on the player for the fight")

	print("TEST PASSED (0 failures)" if failures == 0 else "TEST FAILED (%d failures)" % failures)
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
