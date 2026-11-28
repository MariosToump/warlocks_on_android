extends SceneTree
## Shop tests (milestone 7): gold, upgrades, Homing Orb purchase, items,
## bots shopping, the shop phase between rounds. Bots are passive dummies.
##   godot --headless --path . -s tools/test_shop.gd

var game: Node
var player: Wizard
var blue: Wizard
var green: Wizard
var purple: Wizard
var failures := 0


func _init() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.bot_ai = false
	game.shrink_arena = false
	game.apply_settings = false
	game.title_screen = false
	game.countdown_time = 0.3
	game.round_over_time = 0.3
	game.shop_time = 60.0
	game.wins_to_take_match = 2
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(3)
	player = game.player
	blue = game.get_node("Wizards/BotBlue")
	green = game.get_node("Wizards/BotGreen")
	purple = game.get_node("Wizards/BotPurple")
	var panel: ShopPanel = game.shop_panel

	print("gold after a round")
	_check(Shop.gold_of(game, player) == 0 and player.get_spell("Q").level == 0, "match starts with 0 gold, level 0")
	await _seconds(0.4)
	blue.take_damage(500, player)
	green.take_damage(500, player)
	purple.take_damage(500) # lava: no kill
	await _seconds(0.45)
	_check(game.state == game.State.SHOP, "shop opens after the round")
	_check(panel.visible, "shop panel shown")
	_check(_panel_has_text(panel, "Time Stop"), "every new spell is listed")
	_check(Shop.gold_of(game, player) == 10 + 2 * 5 + 5, "base 10 + 2 kills x5 + win 5 = %d" % Shop.gold_of(game, player))
	_check(blue.get_spell("Q").level == 1 and Shop.gold_of(game, blue) == 0, "bots spend their gold (blue Q lv %d, %d gold)" % [blue.get_spell("Q").level, Shop.gold_of(game, blue)])

	print("upgrades")
	var q := player.get_spell("Q") as FireballSpell
	_check(Shop.upgrade_cost(player, "Q") == 10, "first upgrade costs 10")
	_check(Shop.upgrade(game, player, "Q") and q.level == 1 and Shop.gold_of(game, player) == 15, "upgrade: level 1, 15 gold left")
	_check(q.damage_by_level[q.level] == 8.0, "level 1 fireball hits harder (8)")
	_check(Shop.upgrade_cost(player, "Q") == 15, "next level costs 15")
	_check(Shop.buy_item(game, player, "ring") and Shop.gold_of(game, player) == 5, "Fire Ring for 10")
	_check(not Shop.buy_item(game, player, "boots") and Shop.gold_of(game, player) == 5, "can't buy what you can't afford")
	panel.refresh()
	await _frames(1) # old rows are freed at the end of the frame
	_check(_panel_has_text(panel, "Sell +5g"), "panel offers to sell the ring")

	print("items")
	game.gold[player] = 200
	_check(Shop.buy_item(game, player, "boots"), "Boots")
	_check(not Shop.buy_item(game, player, "cloak") and player.items.size() == 2, "at most 2 items")
	var g0 := Shop.gold_of(game, player)
	_check(Shop.sell_item(game, player, "ring") and Shop.gold_of(game, player) == g0 + 5 and player.items == ["boots"], "selling refunds half")
	_check(is_equal_approx(player.lava_multiplier, 1.0), "sold ring stops working")
	_check(is_equal_approx(player.speed_multiplier, 1.15), "Boots: +15% speed")
	player.move_dir = Vector2.RIGHT
	var walk: float = player._walk_velocity().length()
	player.move_dir = Vector2.ZERO
	_check(absf(walk - 165.0 * 1.15) < 0.5, "walks faster (%.1f px/s)" % walk)
	Shop.buy_item(game, player, "gem")
	_check(is_equal_approx(player.cooldown_multiplier, 0.9), "Focus Gem: -10% cooldowns")
	player.cast("Q", player.global_position + Vector2(100, 0))
	await _seconds(0.4)
	# The cooldown starts with the cast: 1.8 x 0.9 = 1.62, minus 0.4 s waited.
	_check(absf(q.cooldown_left - (q.cooldown() * 0.9 - 0.4)) < 0.08, "fireball cooldown shortened (%.2f)" % q.cooldown_left)
	Shop.sell_item(game, player, "boots")
	Shop.buy_item(game, player, "cloak")
	player.knockback = Vector2.ZERO
	var expect := 100.0 * (1.0 + player.damage_taken * player.knockback_per_damage) * 0.8
	player.apply_knockback(Vector2(100, 0))
	_check(absf(player.knockback.x - expect) < 0.01, "Stone Cloak: -20%% knockback (%.1f)" % player.knockback.x)
	player.knockback = Vector2.ZERO
	Shop.sell_item(game, player, "gem")
	Shop.buy_item(game, player, "ring")
	_check(is_equal_approx(player.lava_multiplier, 0.5), "Fire Ring: half lava damage")

	print("homing orb")
	_check(player.get_spell("D") == null, "no slot D before buying")
	_check(Shop.buy_spell(game, player, "homing") and player.get_spell("D") is HomingOrbSpell, "Homing Orb lands in slot D")
	_check(not Shop.buy_spell(game, player, "homing"), "can't buy it twice")
	_check(Shop.upgrade_cost(player, "D") == 10, "and it can be upgraded")
	panel.refresh()
	await _frames(1) # old rows are freed at the end of the frame
	_check(not _panel_has_text(panel, "Homing Orb\n"), "panel stops offering it")

	print("two shop slots (v0.12)")
	game.gold[player] = 100
	_check(player.slot_of("homing") == "D", "slot_of finds the Homing Orb in D")
	_check(Shop.buy_spell(game, player, "mirror") and player.get_spell("F") is DarkMirrorSpell, "Dark Mirror lands in F")
	var g1 := Shop.gold_of(game, player)
	_check(not Shop.can_buy_spell(game, player, "boomerang") and not Shop.buy_spell(game, player, "boomerang") \
		and Shop.gold_of(game, player) == g1, "both slots full: can't buy a third, no gold taken")
	panel.refresh()
	await _frames(1)
	_check(_panel_has_text(panel, "Sell +7g"), "panel offers to sell a bought spell")
	_check(Shop.sell_spell(game, player, "homing") and Shop.gold_of(game, player) == g1 + 7 \
		and player.get_spell("D") == null, "selling the orb refunds half (7) and frees D")
	await _frames(1)
	_check(Shop.buy_spell(game, player, "boomerang") and player.slot_of("boomerang") == "D", "Boomerang takes the free slot")
	Shop.sell_spell(game, player, "boomerang")
	Shop.sell_spell(game, player, "mirror")
	await _frames(1)
	_check(Shop.buy_spell(game, player, "meteor") and player.slot_of("meteor") == "F", "Meteor takes its home slot F")
	_check(Shop.buy_spell(game, player, "swap") and player.slot_of("swap") == "D", "Swap takes D")
	Shop.sell_spell(game, player, "meteor")
	Shop.sell_spell(game, player, "swap")
	await _frames(1)
	Shop.buy_spell(game, player, "homing")
	game.gold[player] = 25

	print("ready starts the next round, buys are kept")
	_check(not game.pause_menu._pause_button.visible, "no pause button over the shop")
	panel.ready_button.pressed.emit()
	await _frames(2)
	_check(game.pause_menu._pause_button.visible, "pause button back after the shop")
	_check(game.state == game.State.COUNTDOWN and game.round_number == 2, "Ready -> round 2 countdown")
	_check(not panel.visible, "panel closed")
	_check(q.level == 1 and player.get_spell("D") != null and player.items.size() == 2, "upgrades, spells and items kept")

	print("shop timer")
	game.shop_time = 0.3
	await _seconds(0.4)
	blue.take_damage(500, player)
	green.take_damage(500, player)
	purple.take_damage(500, player)
	await _frames(2)
	_check(game.state == game.State.ROUND_OVER and game.match_winner == player, "player wins the match (2 / 2)")
	await _seconds(0.5)
	_check(game.state == game.State.MATCH_OVER and not panel.visible, "no shop after the winning round")

	print("new match clears everything")
	game.start_match()
	await _frames(2)
	_check(q.level == 0 and player.get_spell("D") == null and player.get_spell("F") == null and player.items.is_empty(), "levels, slots D + F and items cleared")
	_check(Shop.gold_of(game, player) == 0 and blue.get_spell("Q").level == 0, "gold 0, bots reset too")
	_check(is_equal_approx(player.lava_multiplier, 1.0) and is_equal_approx(player.knockback_taken_multiplier, 1.0), "item effects gone")
	game.wins_to_take_match = 5
	await _seconds(0.4)
	blue.take_damage(500, player)
	green.take_damage(500, player)
	purple.take_damage(500, player)
	await _seconds(0.35)
	_check(game.state == game.State.SHOP, "shop open again")
	await _seconds(0.4)
	_check(game.state == game.State.COUNTDOWN, "time's up -> next round without Ready")

	# Broke with nothing to sell: no shop, straight to the next round.
	for item in player.items.duplicate():
		Shop.sell_item(game, player, item)
	game.gold[player] = 0
	_check(not Shop.can_shop(game, player), "nothing to buy with 0 gold")
	game.gold[player] = -game.round_income(player) # what the round pays brings it to 0
	game.open_shop()
	_check(game.state == game.State.COUNTDOWN and game.shop_skipped, "shop skipped when broke")
	game.gold[player] = 10
	_check(Shop.can_shop(game, player), "10 gold buys something")

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _panel_has_text(panel: Control, text: String) -> bool:
	for n in panel.find_children("*", "Button", true, false) + panel.find_children("*", "Label", true, false):
		if not n.is_queued_for_deletion() and n.text.contains(text):
			return true
	return false


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(s: float) -> void:
	await create_timer(s).timeout
