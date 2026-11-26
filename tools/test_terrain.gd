extends SceneTree
## Rocks (v0.9): pillars and boulders block spells; boulders get shoved,
## roll into wizards (damage + push, credited) and sink in lava; bots don't
## shoot into rocks. Rock Wall spell and fireball craters.
##   godot --headless --path . -s tools/test_terrain.gd

var game: Node
var player: Wizard
var blue: Wizard
var green: Wizard
var purple: Wizard
var c: Vector2
var failures := 0


func _init() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.bot_ai = false
	game.rounds = false
	game.apply_settings = false
	game.title_screen = false
	game.feel_effects = false
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(3)
	player = game.player
	blue = game.get_node("Wizards/BotBlue")
	green = game.get_node("Wizards/BotGreen")
	purple = game.get_node("Wizards/BotPurple")
	player.get_node("PlayerController").process_mode = Node.PROCESS_MODE_DISABLED
	c = game.arena.get_center()
	_place(green, c + Vector2(-500, -400))
	_place(purple, c + Vector2(-500, 400))

	print("a pillar blocks a fireball")
	var pillar := _rock(Prop.Kind.PILLAR, c + Vector2(100, 0))
	_place(player, c)
	_place(blue, c + Vector2(200, 0))
	var hp := blue.health
	player.cast("Q", blue.global_position)
	await _seconds(0.8)
	_check(is_equal_approx(blue.health, hp), "the wizard behind it isn't hit")
	_check(is_instance_valid(pillar) and pillar.global_position.distance_to(c + Vector2(100, 0)) < 1.0, "the pillar doesn't move")

	print("and lightning")
	player.get_spell("E").cooldown_left = 0.0
	_place(blue, c + Vector2(170, 0))
	await _frames(2)
	player.cast("E", blue.global_position)
	await _seconds(0.6)
	_check(is_equal_approx(blue.health, hp), "lightning stops at the pillar")

	print("bots don't shoot into rocks")
	var ai := AIController.new()
	ai.profile = game.PROFILES[1]
	ai.process_mode = Node.PROCESS_MODE_DISABLED
	blue.add_child(ai)
	ai.target = player
	_check(ai._rock_in_the_way(), "sees the pillar in the way")
	_check(ai._score_fireball() == 0.0 and ai._score_lightning() == 0.0, "no fireball / lightning into it")
	pillar.queue_free()
	await _frames(2)
	_check(not ai._rock_in_the_way(), "clear once it's gone")
	ai.queue_free()

	print("a boulder gets shoved and rolls into a wizard")
	player.get_spell("Q").cooldown_left = 0.0
	var boulder := _rock(Prop.Kind.BOULDER, c + Vector2(60, 0))
	_place(blue, c + Vector2(150, 0))
	blue.last_attacker = null
	hp = blue.health
	player.cast("Q", c + Vector2(200, 0))
	await _seconds(0.9)
	_check(boulder.global_position.x > c.x + 75.0, "the fireball shoves it (%.0f px)" % (boulder.global_position.x - c.x - 60.0))
	_check(blue.health < hp, "it rolls into the wizard behind (hp %.0f)" % blue.health)
	_check(blue.last_attacker == player, "credited to whoever shoved it")

	print("the staff shoves a boulder too")
	var b2 := _rock(Prop.Kind.BOULDER, c + Vector2(0, 120))
	_place(player, c + Vector2(0, 92))
	await _frames(2)
	player.get_spell("A").cooldown_left = 0.0
	player.cast("A", b2.global_position)
	await _seconds(0.5)
	_check(b2.global_position.y > c.y + 125.0, "staff push (%.0f px)" % (b2.global_position.y - c.y - 120.0))

	print("a boulder sinks in lava")
	var edge := c + Vector2(game.arena.radius_tiles * game.arena.tile_size - 40.0, 0)
	var b3 := _rock(Prop.Kind.BOULDER, edge)
	b3.push(Vector2(900, 0), player)
	await _seconds(1.5)
	_check(not is_instance_valid(b3) or b3.sinking, "rolled into the lava and sank")

	print("Rock Wall")
	game.gold[player] = 100
	_check(Shop.buy_spell(game, player, "rockwall"), "buy Rock Wall in the shop (slot F)")
	var wall_spell := player.get_spell("F") as RockWallSpell
	_place(player, c)
	_place(blue, c + Vector2(300, 0))
	hp = blue.health
	await _frames(2)
	_check(player.cast("F", c + Vector2(200, 0)), "cast it toward the right")
	await _seconds(0.3)
	var walls := get_nodes_in_group("props").filter(func(n): return n.kind == Prop.Kind.WALL)
	_check(walls.size() == 3, "3 rocks come up (%d)" % walls.size())
	var mid := Vector2.ZERO
	for r in walls:
		mid += r.global_position / walls.size()
	_check(mid.distance_to(c + Vector2(wall_spell.distance, 0)) < 3.0, "in front of the caster, across the aim")
	blue.cast("Q", player.global_position)
	await _seconds(0.9)
	_check(is_equal_approx(player.health, 100.0), "the wall blocks a fireball")
	await _seconds(wall_spell.life_by_level[0])
	await _frames(20)
	walls = get_nodes_in_group("props").filter(func(n): return n.kind == Prop.Kind.WALL)
	_check(walls.is_empty(), "and crumbles after %.0f s" % wall_spell.life_by_level[0])

	print("fireball craters")
	for n in get_nodes_in_group("craters") + get_nodes_in_group("props"):
		n.free() # (an earlier boulder rolled right where this one bursts)
	player.get_spell("Q").cooldown_left = 0.0
	_place(player, c)
	_place(blue, c + Vector2(160, 0))
	await _frames(2)
	player.cast("Q", blue.global_position)
	await _seconds(0.8)
	var craters := get_nodes_in_group("craters")
	_check(craters.size() == 1 and (craters[0] as Node2D).global_position.distance_to(c + Vector2(150, 0)) < 30.0, "a crater where it burst (%d)" % craters.size())
	if craters.size() == 1:
		var at: Vector2 = craters[0].global_position
		_check(Crater.speed_at(self, at) < 1.0 and Crater.speed_at(self, at + Vector2(80, 0)) == 1.0, "slows only inside")
		_place(green, at - Vector2(10, 0))
		green.knockback = Vector2.ZERO
		green.move_dir = Vector2.RIGHT
		var x0 := green.global_position.x
		await _seconds(0.25)
		var slow_px := green.global_position.x - x0
		green.move_dir = Vector2.ZERO
		_check(slow_px > 0.0 and slow_px < green.move_speed * 0.25 * 0.75, "walking through it is slower (%.0f px)" % slow_px)
		await _seconds(Crater.LIFE)
		_check(get_nodes_in_group("craters").is_empty(), "it cools and goes away")

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _rock(k: Prop.Kind, at: Vector2) -> Prop:
	var p := Prop.make(k, at, game.arena)
	game.get_node("Wizards").add_child(p)
	return p


func _place(w: Wizard, at: Vector2) -> void:
	w.reset(at)
	w.reset_physics_interpolation()


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(s: float) -> void:
	await create_timer(s).timeout
