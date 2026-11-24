extends SceneTree
## Mobile test: simulated touches drive the joystick and spell buttons.
##   godot --path . -s tools/test_touch.gd -- <screenshot_dir>

var game: Node
var player: Wizard
var touch: TouchControls
var out_dir := ""
var failures := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ""
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(5)
	player = game.get_node("Wizards/Player")
	touch = game.get_node("HUD/TouchControls")
	var c: Vector2 = game.get_node("Arena").get_center()
	_check(touch.wizard == player, "touch controls drive the player")

	# Joystick: finger down on the left, drag right.
	var start := player.global_position
	_touch(0, Vector2(250, 500), true)
	_drag(0, Vector2(330, 500))
	await _seconds(0.5)
	_check(player.move_dir.x > 0.9, "joystick sets move_dir (%s)" % player.move_dir)
	_check(player.global_position.x - start.x > 50.0, "player walks right (%.0f px)" % (player.global_position.x - start.x))
	await _shot("1_joystick")
	_touch(0, Vector2(330, 500), false)
	await _frames(2)
	_check(player.move_dir == Vector2.ZERO, "release stops")

	# Tap Q: auto-aims at the nearest enemy.
	await _seconds(0.3)
	var q_pos := touch._button_center("Q")
	_touch(1, q_pos, true)
	_touch(1, q_pos, false)
	_check(player.is_casting() and player.get_spell("Q").cooldown_left > 0.0, "tap Q casts fireball")
	await _seconds(0.2)
	var p := _find_projectile()
	var enemy := touch._nearest_enemy()
	_check(p != null and enemy != null and p.direction.dot((enemy.global_position - player.global_position).normalized()) > 0.98, "tap auto-aims at nearest enemy")
	await _seconds(0.6)

	# Drag W left, release: blink left.
	player.global_position = c
	await _frames(2)
	var w_pos := touch._button_center("W")
	_touch(2, w_pos, true)
	_drag(2, w_pos + Vector2(-140, 0))
	await _frames(3)
	await _shot("2_aim_blink")
	_touch(2, w_pos + Vector2(-140, 0), false)
	await _seconds(0.2)
	_check(c.x - player.global_position.x > 180.0, "drag-aimed blink goes left (%.0f px)" % (c.x - player.global_position.x))

	# Drag E but come back onto the button: cancelled.
	var e_pos := touch._button_center("E")
	_touch(3, e_pos, true)
	_drag(3, e_pos + Vector2(0, -120))
	await _frames(3)
	await _shot("3_aim_lightning")
	_drag(3, e_pos + Vector2(0, -30))
	_touch(3, e_pos + Vector2(0, -30), false)
	await _frames(3)
	_check(player.get_spell("E").cooldown_left == 0.0, "drag back onto button cancels")

	# R: instant shield on touch.
	var r_pos := touch._button_center("R")
	_touch(4, r_pos, true)
	await _seconds(0.2)
	_touch(4, r_pos, false)
	_check(player.is_shielded(), "touching R raises the shield")

	# Two fingers at once: walk while aiming.
	_touch(5, Vector2(250, 500), true)
	_drag(5, Vector2(250, 420))
	_touch(6, e_pos, true)
	_drag(6, e_pos + Vector2(-120, -40))
	await _seconds(0.3)
	_check(player.move_dir.y < -0.9, "walking with one thumb...")
	_check(touch._aim_slot == "E", "...while aiming with the other")
	await _shot("4_multitouch")
	_touch(6, e_pos + Vector2(-120, -40), false)
	_touch(5, Vector2(250, 420), false)
	await _seconds(0.2)
	_check(player.get_spell("E").cooldown_left > 0.0, "lightning cast on release")

	# Attack button: swings on the spot, never walks toward anyone.
	await _seconds(0.6)
	var enemy2 := touch._nearest_enemy()
	player.global_position = enemy2.global_position + Vector2(-110, 0)
	player.reset_physics_interpolation()
	await _frames(2)
	var hp := enemy2.health
	var before := player.global_position
	var a_pos := touch._button_center("A")
	_touch(7, a_pos, true)
	_touch(7, a_pos, false)
	_check(player.is_casting(), "tap attack swings at once")
	await _seconds(0.8)
	_check(player.global_position.distance_to(before) < 2.0, "attack doesn't walk anywhere")
	_check(is_equal_approx(enemy2.health, hp), "out of reach: no hit")
	_check(player.attack_target == null, "no auto-target")

	# In reach: turns to the enemy and hits; holding keeps swinging.
	player.global_position = enemy2.global_position + Vector2(0, 24)
	enemy2.knockback = Vector2.ZERO
	player.reset_physics_interpolation()
	await _frames(2)
	_touch(7, a_pos, true)
	await _seconds(0.3)
	_check(enemy2.health < hp, "hits an enemy in reach (hp %.1f)" % enemy2.health)
	_check(player.get_spell("A").cooldown_left > 0.0, "attack cooldown runs (timer on the button)")
	await _shot("5_attack")
	await _seconds(0.5)
	_check(player.is_casting(), "holding swings again")
	_touch(7, a_pos, false)

	# Zoomed in: 3 screen px per art pixel at 1080p-height screens, 2 here.
	var cam: ArenaCamera = game.get_node("Arena").camera
	_check(cam.zoom.x * cam.screen_scale() >= 2.0, "zoom %.2f px per art px" % (cam.zoom.x * cam.screen_scale()))

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _touch(i: int, pos: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = pos
	e.pressed = down
	root.push_input(e)


func _drag(i: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = pos
	root.push_input(e)


func _find_projectile() -> Projectile:
	for n in game.get_node("Wizards").get_children():
		if n is Projectile and not n.is_queued_for_deletion():
			return n
	return null


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(s: float) -> void:
	await create_timer(s).timeout


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await _frames(1)
	root.get_texture().get_image().save_png("%s/mob_%s.png" % [out_dir, name])
