extends SceneTree
## Staff lock-on (2026-11-28, everyone): a swing started on a warlock with
## Wizard.attack() lands on them if they're within LOCK_REACH when the staff
## comes down; chasing within LOCK_RANGE is 1.3x faster. Free swings unchanged.
##   godot --headless --path . -s tools/test_staff_lock.gd

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
	game.shrink_arena = false
	game.rounds = false
	game.get_node("Arena").platform_radius_tiles = 38.0
	game.apply_settings = false
	game.title_screen = false
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(5)
	player = game.get_node("Wizards/Player")
	blue = game.get_node("Wizards/BotBlue")
	green = game.get_node("Wizards/BotGreen")
	purple = game.get_node("Wizards/BotPurple")
	c = game.get_node("Arena").get_center()
	player.get_node("PlayerController").process_mode = Node.PROCESS_MODE_DISABLED

	print("locked swing follows a target that steps away")
	await _setup(25.0)
	player.attack(blue, true)
	await _until(func(): return player.is_casting(), 1.0)
	_place(blue, c + Vector2(40, 0)) # steps away during the wind-up
	await _seconds(0.4)
	_check(blue.health < 100.0, "hit at 40 px (health %.1f)" % blue.health)

	print("too far at release: a miss")
	await _setup(25.0)
	player.attack(blue, true)
	await _until(func(): return player.is_casting(), 1.0)
	_place(blue, c + Vector2(60, 0))
	await _seconds(0.4)
	_check(is_equal_approx(blue.health, 100.0), "no hit at 60 px")

	print("chase boost")
	await _setup(80.0)
	player.attack(blue)
	await _frames(3)
	var near := player.velocity.length()
	_check(near > 165.0 * 1.25, "1.3x within 85 px (%.0f)" % near)
	await _setup(150.0)
	player.attack(blue)
	await _frames(3)
	var far := player.velocity.length()
	_check(far < 165.0 * 1.05 and far > 100.0, "normal speed beyond 85 px (%.0f)" % far)
	player.attack(null)

	print("free swing unchanged")
	await _setup(40.0)
	player.cast("A", c + Vector2(-50, 0)) # facing away
	await _seconds(0.4)
	_check(is_equal_approx(blue.health, 100.0), "a swing at a point doesn't hit someone behind")

	print("locked target dies during the wind-up")
	await _setup(25.0)
	player.attack(blue, true)
	await _until(func(): return player.is_casting(), 1.0)
	blue.take_damage(999.0, null)
	await _seconds(0.4)
	_check(not blue.alive and player.attack_target == null, "no error, the chase ends")

	print("TEST PASSED" if failures == 0 else "TEST FAILED (%d)" % failures)
	quit(1 if failures else 0)


func _setup(gap: float) -> void:
	for p in get_nodes_in_group("projectiles"):
		p.queue_free()
	player.attack(null)
	_place(green, c + Vector2(-900, -300))
	_place(purple, c + Vector2(-900, 300))
	_place(player, c)
	_place(blue, c + Vector2(gap, 0))
	for w in [player, blue]:
		for s in w.get_node("Spells").get_children():
			(s as Spell).cooldown_left = 0.0
	await _seconds(0.6) # cast and knockback from the last check settle


func _place(w: Wizard, at: Vector2) -> void:
	w.reset(at)


func _until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while not cond.call() and t < limit:
		await physics_frame
		t += 1.0 / 60.0


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(s: float) -> void:
	await create_timer(s).timeout
