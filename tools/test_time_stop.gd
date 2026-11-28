extends SceneTree
## Time Stop (reworked 2026-11-28): freezes enemy wizards inside the circle
## (no walking, no casting), never its caster; spells fly through; hits inside
## push 20% harder and a wizard hit inside keeps that for 2.5 s after it gets
## out; knockback still moves a frozen wizard; bots use it and follow up.
##   godot --headless --path . -s tools/test_time_stop.gd

const NORMAL := preload("res://ai/profiles/normal.tres")
const CASTER := preload("res://ai/personalities/caster.tres")

var game: Node
var player: Wizard
var blue: Wizard
var green: Wizard
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
	c = arena.get_center()
	player.get_node("PlayerController").process_mode = Node.PROCESS_MODE_DISABLED
	(game.get_node("Wizards/BotPurple") as Wizard).reset(c + Vector2(-900, 600))
	game.state = game.State.FREE
	game.gold[player] = 100
	Shop.buy_spell(game, player, "timestop")
	var spell := player.get_spell(player.slot_of("timestop")) as TimeStopSpell
	var dur := spell.duration_by_level[0]

	print("freezes the wizards inside, not its caster")
	_reset_all()
	var at := c + Vector2(300, 0)
	player.reset(at + Vector2(-60, 0)) # the caster stands in its own field
	blue.reset(at)
	green.reset(at + Vector2(0, 200)) # outside
	await _frames(2)
	spell.release(at)
	await _frames(2)
	_check(blue.frozen and not player.frozen and not green.frozen, "blue frozen; caster and outsider free")
	blue.move_dir = Vector2.RIGHT
	player.move_dir = Vector2.DOWN
	await _seconds(0.5)
	_check(blue.global_position.distance_to(at) < 1.0, "a frozen wizard can't walk")
	_check(player.global_position.distance_to(at + Vector2(-60, 0)) > 30.0, "the caster walks normally inside")
	blue.move_dir = Vector2.ZERO
	player.move_dir = Vector2.ZERO
	_check(not blue.cast("Q", c), "a frozen wizard can't cast")
	await _seconds(dur - 0.5 + 0.1)
	_check(not blue.frozen and blue.cast("Q", c + Vector2(0, 300)), "free again after %.1f s, and can cast" % dur)

	print("spells fly through")
	_reset_all()
	player.reset(c)
	blue.reset(c + Vector2(400, -150))
	await _frames(2)
	spell.release(c + Vector2(250, 0))
	await _frames(1)
	blue.get_spell("Q").release(c + Vector2(400, 250))
	var fb := _projectile()
	var p0 := fb.global_position
	await _seconds(0.4)
	_check(is_instance_valid(fb) and fb.global_position.distance_to(p0) > 150.0, "a fireball through the circle isn't stopped")

	print("hits inside push 20% harder; the mark lasts after")
	_reset_all()
	player.reset(c)
	blue.reset(c + Vector2(300, 0))
	green.reset(c + Vector2(300, 300))
	await _frames(2)
	spell.release(c + Vector2(300, 0))
	await _frames(2)
	blue.apply_knockback(Vector2(100, 0))
	green.apply_knockback(Vector2(100, 0))
	_check(is_equal_approx(blue.knockback.x / green.knockback.x, 1.2), "x1.2 inside (%.2f)" % (blue.knockback.x / green.knockback.x))
	await _seconds(0.3)
	_check(blue.global_position.x > c.x + 310.0, "knockback still moves a frozen wizard")
	await _seconds(dur)
	_check(not blue.frozen and blue.time_mark_left > 1.5 and is_equal_approx(blue.time_knockback(), 1.2),
		"out of it, still marked (%.1f s left)" % blue.time_mark_left)
	await _seconds(2.6)
	_check(is_equal_approx(blue.time_knockback(), 1.0), "the mark wears off after 2.5 s")

	print("only wizards hit inside are marked")
	_reset_all()
	player.reset(c)
	blue.reset(c + Vector2(300, 0))
	await _frames(2)
	spell.release(c + Vector2(300, 0))
	await _seconds(dur + 0.1)
	_check(is_equal_approx(blue.time_knockback(), 1.0), "frozen but never hit: no mark after")

	print("bots")
	_reset_all()
	var ai := AIController.new()
	ai.personality = CASTER
	ai.profile = NORMAL
	green.add_child(ai)
	ai.process_mode = Node.PROCESS_MODE_DISABLED
	game.gold[green] = 100
	Shop.buy_spell(game, green, "timestop")
	Shop.buy_spell(game, green, "meteor")
	green.reset(c)
	player.reset(c + Vector2(0, -150))
	blue.reset(c + Vector2(350, 0))
	await _frames(2)
	ai.target = blue
	_check(ai._score_timestop() > 0.0, "scores Time Stop on a target in range (%.2f)" % ai._score_timestop())
	var meteor_free := ai._score_meteor()
	spell.release(blue.global_position)
	await _frames(2)
	_check(ai._score_timestop() == 0.0, "not on a target that's already frozen")
	_check(ai._score_meteor() > meteor_free, "a frozen target makes the Meteor score higher (%.2f > %.2f)" % [ai._score_meteor(), meteor_free])
	ai.free()

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _reset_all() -> void:
	for g in ["projectiles", "time_stops", "meteors"]:
		for p in get_nodes_in_group(g):
			p.free()
	for w in [player, blue, green]:
		w.reset(c + Vector2(-800, w.get_index() * 150))
		for s in w.get_node("Spells").get_children():
			(s as Spell).cooldown_left = 0.0


func _projectile() -> Projectile:
	for n in get_nodes_in_group("projectiles"):
		if n is Projectile and not n.is_queued_for_deletion():
			return n
	return null


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(s: float) -> void:
	await _frames(roundi(s * 60.0))
