extends SceneTree
## Ghost mode (v0.9): the player dies mid-fight -> a ghost that floats with
## the joystick, can't be hit, haunts (shoves, no damage, no kill credit),
## and is gone at round end / on Quit to menu.
##   godot --headless --path . -s tools/test_ghost.gd

var game: Node
var player: Wizard
var blue: Wizard
var green: Wizard
var purple: Wizard
var touch: TouchControls
var failures := 0


func _init() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.bot_ai = false
	game.apply_settings = false
	game.title_screen = false
	game.shrink_arena = false
	game.countdown_time = 0.3
	game.round_over_time = 0.3
	game.shop_time = 0.02
	game.spectate_delay = 0.3
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(3)
	player = game.player
	blue = game.get_node("Wizards/BotBlue")
	green = game.get_node("Wizards/BotGreen")
	purple = game.get_node("Wizards/BotPurple")
	touch = game.touch
	player.get_node("PlayerController").process_mode = Node.PROCESS_MODE_DISABLED
	var c: Vector2 = game.arena.get_center()
	await _seconds(0.5)
	_check(game.state == game.State.FIGHT, "fight on")

	print("dying makes a ghost")
	player.take_damage(500.0, blue)
	await _frames(2)
	_check(game.ghost == null, "not straight away")
	await _seconds(0.4)
	var g: Ghost = game.ghost
	_check(g != null and g.global_position.distance_to(player.global_position) < 2.0, "a ghost after the delay, where you fell")
	_check(game.arena.camera.target == g, "camera follows the ghost")
	_check(not g.is_in_group("wizards"), "bots can't see it")

	print("floats with the joystick, over lava, unharmed")
	var start := g.global_position
	player.move_dir = Vector2.RIGHT
	await _seconds(0.5)
	_check(g.global_position.x - start.x > 80.0, "moves with move_dir (%.0f px)" % (g.global_position.x - start.x))
	var e := c + Vector2(game.arena.platform_radius_tiles * game.arena.tile_size + 60.0, 0)
	g.global_position = e
	await _seconds(0.3)
	_check(game.arena.is_lava_at(g.global_position) and is_instance_valid(g), "floats over lava")
	player.move_dir = Vector2.ZERO
	_check(is_equal_approx(Ghost.SPEED, player.move_speed * 3.5), "3.5x walking speed (%.0f)" % Ghost.SPEED)

	print("tap the minimap to fly there")
	var mm: Minimap = game.minimap
	var spot := c + Vector2(-200, 150)
	var tap := mm.get_global_rect().position + mm.to_map(spot)
	touch._touch_down(2, tap)
	touch._touch_up(2)
	_check(g.global_position.distance_to(spot) < 12.0, "ghost jumps to the tapped spot (%.0f px off)" % g.global_position.distance_to(spot))
	_check(touch._stick_index != 2, "the tap doesn't grab the joystick")
	var corner := mm.get_global_rect().position + Vector2(2, 2) # outside the disc
	g.global_position = c
	touch._touch_down(2, corner)
	touch._touch_up(2)
	_check(g.global_position == c, "outside the disc: no jump")

	print("haunt")
	for w in [blue, green, purple]:
		w.knockback = Vector2.ZERO
	green.global_position = c + Vector2(-600, 0)
	purple.global_position = c + Vector2(0, 600)
	blue.global_position = c
	blue.last_attacker = null
	g.global_position = c + Vector2(-40, 0)
	await _frames(2)
	var hp := blue.health
	touch._touch_down(1, touch._button_center("A")) # (headless: no real touches)
	touch._touch_up(1)
	await _frames(1)
	_check(blue.knockback.x > 100.0, "the attack button haunts: shoves a wizard close by (%.0f)" % blue.knockback.x)
	_check(is_equal_approx(blue.health, hp) and blue.last_attacker == null, "no damage, no kill credit")
	_check(green.knockback == Vector2.ZERO, "far wizards untouched")
	blue.knockback = Vector2.ZERO
	blue.global_position = c
	g.global_position = c + Vector2(-40, 0)
	_check(not g.haunt(), "cooldown")
	_check(not touch._shown("Q") and touch._button_at(touch._button_center("W")) == "", "spell buttons hidden while a ghost")
	_check(touch.marker_targets().is_empty(), "no staff markers while a ghost")
	_check(touch._button_at(touch._button_center("A")) == "A", "attack button stays (haunt)")

	print("projectiles go through it")
	var hits_before := player.health
	blue.cast("Q", g.global_position)
	await _seconds(0.5)
	_check(is_instance_valid(g) and player.health == hits_before, "nothing can hit a ghost")

	print("gone at round end")
	green.take_damage(500.0, blue)
	purple.take_damage(500.0, blue)
	await _frames(3)
	_check(game.state == game.State.ROUND_OVER, "round over")
	_check(game.ghost == null and not is_instance_valid(g) or g.is_queued_for_deletion(), "ghost removed")
	_check(game.arena.camera.target != null and is_instance_valid(game.arena.camera.target), "camera on someone real")
	_check(touch._button_at(touch._button_center("Q")) == "Q", "spell buttons back")

	print("gone on Quit to menu")
	await _seconds(1.0) # shop skipped / next round
	while game.state != game.State.FIGHT:
		await _frames(1)
	player.take_damage(500.0, blue)
	await _seconds(0.5)
	_check(game.ghost != null, "ghost again next round")
	game.enter_title()
	await _frames(2)
	_check(game.ghost == null and touch.ghost == null, "Quit to menu removes it")

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _touch(i: int, pos: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = i
	ev.position = pos
	ev.pressed = down
	root.push_input(ev)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(s: float) -> void:
	await create_timer(s).timeout
