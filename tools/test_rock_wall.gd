extends SceneTree
## Rock Wall on its own (spell audit 2026-11-27: it only had a line in
## test_terrain): rocks across the aim, they block spells, none on lava, a
## wizard where a rock rises is bumped aside, they crumble on time (also when
## the caster is dead), and the bot raises one against a spell coming in.
##   godot --headless --path . -s tools/test_rock_wall.gd

const NORMAL := preload("res://ai/profiles/normal.tres")
const CASTER := preload("res://ai/personalities/caster.tres")

var game: Node
var player: Wizard
var blue: Wizard
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
	c = arena.get_center()
	player.get_node("PlayerController").process_mode = Node.PROCESS_MODE_DISABLED
	for n in ["BotGreen", "BotPurple"]:
		(game.get_node("Wizards/" + n) as Wizard).reset(c + Vector2(-900, 600))
	game.state = game.State.FREE
	_clear()
	game.gold[player] = 100
	Shop.buy_spell(game, player, "rockwall")
	var slot := player.slot_of("rockwall")
	var spell := player.get_spell(slot) as RockWallSpell
	_check(spell != null, "Rock Wall bought into " + slot)

	print("shape")
	player.reset(c)
	blue.reset(c + Vector2(-500, 0))
	await _frames(2)
	spell.release(c + Vector2(300, 0))
	await _frames(2)
	var rocks := _walls()
	_check(rocks.size() == spell.rocks, "%d rocks come up" % rocks.size())
	var ok := true
	for r in rocks:
		if absf(r.global_position.x - (c.x + spell.distance)) > 1.0:
			ok = false
	_check(ok, "in a line %d px in front, across the aim" % int(spell.distance))
	_check(absf(rocks[0].global_position.y - rocks[-1].global_position.y) > spell.spacing * 1.5, "spread across the aim")

	print("blocks a spell")
	blue.reset(c + Vector2(400, 0))
	await _frames(2)
	blue.cast("Q", player.global_position)
	await _seconds(1.5)
	_check(player.health == player.max_health, "the fireball hits the wall, not you (hp %.0f)" % player.health)

	print("crumbles")
	await _seconds(spell.life_by_level[0])
	_check(_walls().is_empty(), "gone after %.1f s" % spell.life_by_level[0])

	print("bumps a wizard aside")
	_clear()
	player.reset(c)
	blue.reset(c + Vector2(spell.distance, 0))
	await _frames(2)
	spell.release(c + Vector2(300, 0))
	await _seconds(0.4)
	_check(blue.global_position.distance_to(c + Vector2(spell.distance, 0)) > 8.0, "a wizard where a rock rises is pushed off it")

	print("not on lava")
	_clear()
	var edge := c
	while not arena.is_lava_at(edge):
		edge += Vector2.RIGHT * 8.0
	player.reset(edge - Vector2(spell.distance, 0) + Vector2(10, 0))
	await _frames(2)
	spell.release(player.global_position + Vector2(300, 0))
	await _frames(2)
	var on_lava := 0
	for r in _walls():
		if arena.is_lava_at(r.global_position):
			on_lava += 1
	_check(on_lava == 0, "no rock comes up out of the lava")

	print("caster dies: the wall stays its time")
	_clear()
	player.reset(c)
	await _frames(2)
	spell.release(c + Vector2(300, 0))
	await _frames(2)
	player.take_damage(1000.0)
	await _seconds(1.0)
	_check(_walls().size() == spell.rocks, "still standing after the caster died")
	await _seconds(spell.life_by_level[0])
	_check(_walls().is_empty(), "and crumbles on time")

	print("bot")
	_clear()
	blue.reset(c)
	player.reset(c + Vector2(400, 0))
	game.gold[blue] = 100
	Shop.buy_spell(game, blue, "rockwall")
	var ai := AIController.new()
	ai.personality = CASTER
	ai.profile = NORMAL
	blue.add_child(ai)
	ai.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(2)
	player.cast("Q", blue.global_position)
	await _seconds(0.35)
	for n in get_nodes_in_group("projectiles"):
		ai._danger = n as Projectile # spotting it is test_ai's job; here: what the bot does about it
	_check(ai._danger != null, "a fireball is coming at the bot")
	if ai._danger:
		ai._rolls[ai._danger.get_instance_id()] = [true, false, 0.0]
	_check(ai._score_rockwall() > 0.0, "and scores a wall even with its shield ready (%.2f)" % ai._score_rockwall())
	ai.free()

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _walls() -> Array[Prop]:
	var out: Array[Prop] = []
	for p in get_nodes_in_group("props"):
		if p is Prop and p.kind == Prop.Kind.WALL and not p.is_queued_for_deletion() and not p.sinking:
			out.append(p)
	return out


func _clear() -> void:
	for g in ["props", "projectiles"]:
		for p in get_nodes_in_group(g):
			p.queue_free()
	for s in player.get_node("Spells").get_children():
		(s as Spell).cooldown_left = 0.0


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(s: float) -> void:
	await _frames(roundi(s * 60.0))
