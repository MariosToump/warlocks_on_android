extends SceneTree
## The v0.12 shop spells: Boomerang, Swap, Meteor, Gravity Well (Time Stop:
## tools/test_time_stop.gd since its 2026-11-28 rework).
## (behaviour + bots). Bots are passive dummies unless a test adds a brain.
##   godot --headless --path . -s tools/test_new_spells.gd

const PERS := {
	"brawler": preload("res://ai/personalities/brawler.tres"),
	"caster": preload("res://ai/personalities/caster.tres"),
	"trickster": preload("res://ai/personalities/trickster.tres"),
}
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
	Platform.forced = Platform.Mode.TOUCH # touch-layer test
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

	await _test_boomerang()
	await _test_swap()
	await _test_meteor()
	await _test_well()

	print("TEST PASSED (0 failures)" if failures == 0 else "TEST FAILED (%d failures)" % failures)
	quit(1 if failures else 0)


# --- Boomerang ---------------------------------------------------------------

func _test_boomerang() -> void:
	print("boomerang")
	_park_all()
	var slot := _give(player, "boomerang")
	_check(player.get_spell(slot) is BoomerangSpell, "bought into slot %s" % slot)
	_place(player, c)
	_place(blue, c + Vector2(200, 0))
	blue.knockback_taken_multiplier = 0.0 # stays on the path both ways
	var hits := [0]
	var count := func(_a, _s): hits[0] += 1
	blue.damaged.connect(count)
	_cast_now(player, slot, c + Vector2(400, 0))
	var b := _find("boomerangs")
	_check(b != null, "a boomerang flies")
	var far := 0.0
	var t := 0.0
	while is_instance_valid(b) and t < 4.0:
		far = maxf(far, b.global_position.distance_to(c))
		await _frames(1)
		t += 1.0 / 60.0
	_check(far > 390.0 and far < 450.0, "flies out about 420 px (%.0f)" % far)
	_check(not is_instance_valid(b) and t < 3.5, "comes back to the caster and is caught (%.1f s)" % t)
	_check(hits[0] == 2, "a wizard on the path is hit going out and coming back (%d hits)" % hits[0])
	blue.damaged.disconnect(count)
	blue.knockback_taken_multiplier = 1.0

	print("boomerang vs shield")
	_park_all()
	_place(player, c)
	_place(green, c + Vector2(150, 0))
	green.raise_shield(2.0)
	_cast_now(player, slot, c + Vector2(400, 0))
	b = _find("boomerangs")
	await _frames(30)
	_check(is_instance_valid(b) and b.caster == green, "a shield turns it: now the shielder's")
	if is_instance_valid(b):
		b.queue_free()

	print("boomerang: bot")
	_park_all()
	var ai := _idle_bot(purple, "trickster")
	_give(purple, "boomerang")
	_place(purple, c)
	_place(blue, c + Vector2(300, 0))
	await _frames(2)
	ai.target = blue
	_check(ai._score_boomerang() > 0.0, "scores the boomerang at 300 px (%.2f)" % ai._score_boomerang())
	_remove_bot(ai)
	Shop.sell_spell(game, player, "boomerang")
	Shop.sell_spell(game, purple, "boomerang")


# --- Swap --------------------------------------------------------------------

func _test_swap() -> void:
	print("swap")
	_park_all()
	var slot := _give(player, "swap")
	var a := c + Vector2(-200, 150)
	var b := a + Vector2(300, 0)
	_place(player, a)
	_place(blue, b)
	_cast_now(player, slot, b)
	await _frames(40)
	# (the headless player creeps up ~12 px on its own in these tests, so
	# compare x and check both ended on the same row)
	_check(absf(player.global_position.x - b.x) < 3.0 and absf(blue.global_position.x - a.x) < 3.0 \
		and absf(player.global_position.y - blue.global_position.y) < 14.0,
		"a hit trades places (player %s, blue %s)" % [player.global_position - c, blue.global_position - c])
	_check(player.knockback == Vector2.ZERO and blue.knockback == Vector2.ZERO, "and nobody keeps flying")

	_park_all()
	_place(player, c)
	_place(blue, c + Vector2(950, 0))
	_cast_now(player, slot, blue.global_position)
	await _frames(90)
	_check(player.global_position.distance_to(c) < 1.0, "out of range: nothing happens")

	_park_all()
	_place(player, c)
	_place(green, c + Vector2(150, 0))
	green.raise_shield(2.0)
	_cast_now(player, slot, green.global_position)
	await _frames(12)
	var orb := _find("projectiles") as Projectile
	_check(orb != null and orb.caster == green, "a shield reflects the orb")
	await _frames(40)

	print("swap: bot")
	_park_all()
	var ai := _idle_bot(blue, "brawler")
	_give(blue, "swap")
	_place(blue, c + Vector2(500, 0))
	_place(green, c + Vector2(200, 0))
	await _frames(2)
	ai.target = green
	_check(ai._score_swap() > 0.0, "scores Swap when it's further out than its target (%.2f)" % ai._score_swap())
	_place(blue, c)
	_place(green, c + Vector2(300, 0))
	_check(ai._score_swap() == 0.0, "not when it's the safer one")
	_remove_bot(ai)
	Shop.sell_spell(game, player, "swap")
	Shop.sell_spell(game, blue, "swap")


# --- Meteor ------------------------------------------------------------------

func _test_meteor() -> void:
	print("meteor")
	_park_all()
	var slot := _give(player, "meteor")
	var at := c + Vector2(300, 0)
	_place(player, c)
	_place(blue, at + Vector2(50, 0))
	_place(green, at + Vector2(0, 120))
	_place(purple, at + Vector2(0, -40))
	purple.raise_shield(3.0)
	_cast_now(player, slot, at)
	await _seconds(0.75)
	_check(is_equal_approx(blue.health, 100.0), "nothing before the 0.85 s warning ends")
	await _seconds(0.3)
	_check(blue.health < 100.0 and blue.knockback.x > 0.0, "then the blast hurts and pushes outward")
	_check(is_equal_approx(blue.health, 80.0), "level 0 hits for 20 (meteor buff 2026-11-28; hp %.0f)" % blue.health)
	_check(blue.knockback.length() > 700.0, "and shoves hard (%.0f px/s, the old meteor ~575 here)" % blue.knockback.length())
	_check(is_equal_approx(green.health, 100.0), "120 px away: untouched")
	_check(is_equal_approx(purple.health, 100.0), "a shield blocks it")
	var crater := false
	for n in get_nodes_in_group("craters"):
		crater = crater or (n as Node2D).global_position.distance_to(at) < 5.0
	_check(crater, "leaves a crater")

	print("meteor: bots")
	_park_all()
	var ai := _idle_bot(green, "caster")
	_give(green, "meteor")
	_place(green, c)
	_place(blue, c + Vector2(400, 0))
	await _frames(2)
	ai.target = blue
	_check(ai._score_meteor() > 0.0, "scores the meteor at 400 px (%.2f)" % ai._score_meteor())
	_remove_bot(ai)
	_park_all()
	var runner := _make_bot(purple, "trickster")
	for s in ["Q", "W", "E", "R", "A"]:
		(purple.get_spell(s) as Spell).cooldown_left = 99.0 # walk only
	_place(purple, c + Vector2(0, 300))
	_place(player, c + Vector2(-300, 300))
	await _frames(2)
	_cast_now(player, slot, purple.global_position + Vector2(30, 0)) # inside the ring, a little off-centre
	await _seconds(1.3)
	_check(get_nodes_in_group("craters").size() > 0 and is_equal_approx(purple.health, 100.0),
		"a bot inside the ring walks out in time (hp %.0f)" % purple.health)
	_remove_bot(runner)
	Shop.sell_spell(game, player, "meteor")
	Shop.sell_spell(game, green, "meteor")


# --- Gravity Well ------------------------------------------------------------

func _test_well() -> void:
	print("gravity well")
	_park_all()
	var slot := _give(player, "well")
	var at := c + Vector2(200, 0)
	_place(player, at + Vector2(-100, 0))
	_place(blue, at + Vector2(120, 0))
	_cast_now(player, slot, at)
	await _seconds(1.0)
	_check(blue.global_position.distance_to(at) < 60.0, "an enemy 120 px out is dragged in (%.0f px)" % blue.global_position.distance_to(at))
	_check(player.global_position.distance_to(at + Vector2(-100, 0)) < 3.0, "the caster isn't pulled")
	await _seconds(1.7)
	_check(get_nodes_in_group("wells").is_empty(), "gone after 2.5 s")

	print("gravity well: bots")
	_park_all()
	var ai := _idle_bot(blue, "brawler")
	_give(blue, "well")
	_place(blue, c)
	_place(green, c + Vector2(300, 0))
	await _frames(2)
	ai.target = green
	_check(ai._score_well() > 0.0, "scores the well at 300 px (%.2f)" % ai._score_well())
	_remove_bot(ai)
	_park_all()
	var runner := _make_bot(purple, "trickster")
	for s in ["Q", "W", "E", "R", "A"]:
		(purple.get_spell(s) as Spell).cooldown_left = 99.0
	at = c + Vector2(0, 300)
	_place(player, at + Vector2(-300, 0))
	_place(purple, at + Vector2(140, 0))
	await _frames(2)
	_cast_now(player, slot, at)
	await _seconds(1.5)
	_check(purple.global_position.distance_to(at) > 140.0, "a bot at the rim walks out (%.0f px)" % purple.global_position.distance_to(at))
	_remove_bot(runner)
	Shop.sell_spell(game, player, "well")
	Shop.sell_spell(game, blue, "well")


# --- helpers -----------------------------------------------------------------

func _seconds(s: float) -> void:
	await _frames(roundi(s * 60.0))


## Buy spell `id` for `w` (free); returns its slot.
func _give(w: Wizard, id: String) -> String:
	game.gold[w] = 100
	Shop.buy_spell(game, w, id)
	return w.slot_of(id)


## Release a spell right away (no cast time), like the spell tests do.
func _cast_now(w: Wizard, slot: String, at: Vector2) -> void:
	var s := w.get_spell(slot)
	s.cooldown_left = 0.0
	s.release(at)


func _find(group: String) -> Node2D:
	var all := get_nodes_in_group(group)
	return all[-1] as Node2D if all.size() > 0 else null


func _make_bot(w: Wizard, pers: String) -> AIController:
	var ai := AIController.new()
	ai.personality = PERS[pers]
	ai.profile = NORMAL
	w.add_child(ai)
	return ai


## A brain that doesn't think on its own (for checking scores).
func _idle_bot(w: Wizard, pers: String) -> AIController:
	var ai := _make_bot(w, pers)
	ai.process_mode = Node.PROCESS_MODE_DISABLED
	return ai


func _remove_bot(ai: AIController) -> void:
	var w := ai.wizard
	ai.free()
	w.move_target = null
	w.move_dir = Vector2.ZERO
	w.attack(null)


func _park_all() -> void:
	for g in ["projectiles", "boomerangs", "meteors", "wells", "time_stops", "props"]:
		for p in get_nodes_in_group(g):
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
