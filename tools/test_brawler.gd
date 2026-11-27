extends SceneTree
## Brawler rework (v0.12): mid range by default, rushes in only on a real
## chance, and the Blink -> staff combo (a rule for every wizard).
##   godot --headless --path . -s tools/test_brawler.gd

const BRAWLER := preload("res://ai/personalities/brawler.tres")
const NORMAL := preload("res://ai/profiles/normal.tres")

var game: Node
var player: Wizard
var blue: Wizard
var green: Wizard
var purple: Wizard
var arena: Arena
var c: Vector2
var failures := 0


func _init() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.bot_ai = false
	game.shrink_arena = false
	game.rounds = false
	game.get_node("Arena").platform_radius_tiles = 38.0
	game.apply_settings = false
	game.title_screen = false
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(5)
	arena = game.get_node("Arena")
	player = game.get_node("Wizards/Player")
	blue = game.get_node("Wizards/BotBlue")
	green = game.get_node("Wizards/BotGreen")
	purple = game.get_node("Wizards/BotPurple")
	c = arena.get_center()
	player.get_node("PlayerController").process_mode = Node.PROCESS_MODE_DISABLED

	_test_combo_knockback()
	_test_combo_window_ends()
	await _test_holds_mid_range()
	await _test_rushes_on_a_chance()
	await _test_no_impatient_rush()
	await _test_blinks_in_during_a_rush()

	print("TEST PASSED (0 failures)" if failures == 0 else "TEST FAILED (%d failures)" % failures)
	quit(1 if failures else 0)


## Staff hit on blue standing 20 px to the right of the player; returns the push.
func _staff_push() -> float:
	_place(blue, player.global_position + Vector2(20, 0))
	(player.get_spell("A") as Spell).release(blue.global_position)
	return blue.knockback.length()


func _test_combo_knockback() -> void:
	print("blink -> staff combo")
	_park_all()
	_place(player, c)
	player.last_blink_at = -100.0
	var plain := _staff_push()
	_place(player, c)
	(player.get_spell("W") as Spell).release(c + Vector2(0, 100))
	_check(GameClock.now() - player.last_blink_at < 0.5, "blink records when it happened")
	var combo := _staff_push()
	_check(plain > 0.0 and combo / plain > 1.35 and combo / plain < 1.45,
		"staff right after a blink pushes ~1.4x harder (%.0f vs %.0f)" % [combo, plain])


func _test_combo_window_ends() -> void:
	print("combo window")
	_park_all()
	_place(player, c)
	player.last_blink_at = -100.0
	var plain := _staff_push()
	_place(player, c)
	player.last_blink_at = GameClock.now() - 1.6
	var late := _staff_push()
	_check(is_equal_approx(late, plain), "1.6 s after the blink: no bonus (%.0f vs %.0f)" % [late, plain])


func _test_holds_mid_range() -> void:
	print("mid range by default")
	_park_all()
	var ai := _make_bot(blue)
	_place(blue, c)
	_place(green, c + Vector2(400, 0))
	await _frames(2)
	ai.target = green
	var hold := ai.preferred_distance()
	_check(hold > 250.0 and hold < 360.0, "healthy target: holds about 300 px (%.0f)" % hold)
	await _cast_and_wait(green, "Q", c + Vector2(400, -300))
	_check(ai.preferred_distance() > 250.0, "target just threw a fireball: still holds (%.0f)" % ai.preferred_distance())
	_remove_bot(ai)


func _test_rushes_on_a_chance() -> void:
	print("rushes on a real chance")
	_park_all()
	var ai := _make_bot(blue)
	_place(blue, c)
	_place(green, c + Vector2(400, 0))
	await _frames(2)
	ai.target = green
	green.health = 25.0
	_check(ai.preferred_distance() > 250.0, "low HP alone: still holds (%.0f)" % ai.preferred_distance())
	green.health = 100.0
	await _cast_and_wait(green, "E", c + Vector2(400, -300))
	ai._now += 3.0
	_check(ai.preferred_distance() > 250.0, "lightning recharging alone: still holds")
	green.health = 25.0
	_check(ai.preferred_distance() < 60.0, "hurt and its lightning recharging: rushes in (%.0f)" % ai.preferred_distance())
	ai._now += 3.0
	_check(ai.preferred_distance() > 250.0, "lightning probably back: holds again")
	green.health = 100.0
	_remove_bot(ai)


func _test_no_impatient_rush() -> void:
	print("no impatient rush")
	_park_all()
	var ai := _make_bot(blue)
	for s in ["Q", "E", "W", "D"]:
		if blue.get_spell(s):
			(blue.get_spell(s) as Spell).cooldown_left = 999.0
	_place(blue, c)
	_place(green, c + Vector2(500, 0))
	green.knockback_taken_multiplier = 0.0
	var closest := INF
	for i in 6 * 60:
		await _frames(1)
		green.health = 100.0
		closest = minf(closest, blue.global_position.distance_to(green.global_position))
	_check(closest > 200.0, "healthy, passive target for 6 s: never rushes (closest %.0f)" % closest)
	green.knockback_taken_multiplier = 1.0
	_remove_bot(ai)


func _test_blinks_in_during_a_rush() -> void:
	print("blinks in during a rush")
	_park_all()
	var ai := _make_bot(blue)
	for s in ["Q", "E", "D"]: # leave Blink and the staff
		if blue.get_spell(s):
			(blue.get_spell(s) as Spell).cooldown_left = 999.0
	_place(blue, c)
	_place(green, c + Vector2(170, 0)) # middle of a big island: no lava near
	green.knockback_taken_multiplier = 0.0
	await _frames(2) # memory starts watching a frame after the bot is added
	await _cast_and_wait(green, "E", c + Vector2(170, -300)) # its lightning is now recharging
	var blinked := false
	for i in 3 * 60:
		await _frames(1)
		green.health = 25.0
		blinked = blinked or (blue.get_spell("W") as Spell).cooldown_left > 0.0
	_check(blinked, "blinks at a hurt target (lightning down) with no lava nearby")
	green.health = 100.0
	green.knockback_taken_multiplier = 1.0
	_remove_bot(ai)


# --- helpers -----------------------------------------------------------------

func _make_bot(w: Wizard) -> AIController:
	var ai := AIController.new()
	ai.personality = BRAWLER
	ai.profile = NORMAL
	w.add_child(ai)
	return ai


func _remove_bot(ai: AIController) -> void:
	var w := ai.wizard
	ai.free()
	w.move_target = null
	w.move_dir = Vector2.ZERO
	w.attack(null)


func _cast_and_wait(w: Wizard, slot: String, at: Vector2) -> void:
	w.get_spell(slot).cooldown_left = 0.0
	w.cast(slot, at)
	await _frames(20)


func _park_all() -> void:
	for p in get_nodes_in_group("projectiles"):
		p.queue_free()
	var spots := [Vector2(-900, -300), Vector2(-900, 300), Vector2(-600, -700), Vector2(-600, 700)]
	var all := [player, blue, green, purple]
	for i in all.size():
		_place(all[i], c + spots[i])
		for s in all[i].get_node("Spells").get_children():
			(s as Spell).cooldown_left = 0.0


func _place(w: Wizard, at: Vector2) -> void:
	w.reset(at)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
