extends SceneTree
## Mobile test: simulated touches drive the joystick and spell buttons.
##   godot --path . -s tools/test_touch.gd -- <screenshot_dir>

var game: Node
var player: Wizard
var touch: TouchControls
var out_dir := ""
var failures := 0


func _init() -> void:
	Platform.forced = Platform.Mode.TOUCH # touch-layer test
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ""
	game = load("res://scenes/game.tscn").instantiate()
	game.bot_ai = false
	game.shrink_arena = false
	game.rounds = false
	game.apply_settings = false
	game.title_screen = false
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(5)
	player = game.get_node("Wizards/Player")
	touch = game.get_node("HUD/TouchControls")
	var c: Vector2 = game.get_node("Arena").get_center()
	_check(touch.wizard == player, "touch controls drive the player")
	_check(game.pc_bar == null and game.touch.visible, "touch mode: no PC bar, touch layer shown")

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

	# v0.9 stick fixes.
	# A thumb put down while locked (countdown) walks once the fight starts.
	touch.locked = true
	_touch(10, Vector2(250, 500), true)
	_drag(10, Vector2(330, 500))
	await _frames(3)
	_check(player.move_dir == Vector2.ZERO, "no walking while locked")
	touch.locked = false
	await _frames(2)
	_check(player.move_dir.x > 0.9, "thumb held through the countdown walks at the start (%s)" % player.move_dir)
	# Its touch-up gets lost; a new thumb still takes the stick.
	_touch(11, Vector2(200, 450), true)
	_drag(11, Vector2(200, 370))
	await _frames(2)
	_check(player.move_dir.y < -0.9, "a new thumb takes over a stuck stick (%s)" % player.move_dir)
	# Past the ring, then reverse: the ring followed, so it flips at once.
	_drag(11, Vector2(200, 150))
	_drag(11, Vector2(200, 270)) # only 120 px back (the old fixed ring needed ~300)
	await _frames(2)
	_check(player.move_dir.y > 0.2, "reversal answers at once after dragging past the ring (%s)" % player.move_dir)
	# A canceled touch (system gesture) releases.
	var cancel := InputEventScreenTouch.new()
	cancel.index = 11
	cancel.position = Vector2(200, 200)
	cancel.pressed = false
	cancel.canceled = true
	root.push_input(cancel)
	await _frames(2)
	_check(player.move_dir == Vector2.ZERO, "canceled touch releases the stick")
	# Small drags ramp up smoothly from the deadzone.
	_touch(12, Vector2(250, 500), true)
	_drag(12, Vector2(250 + TouchControls.STICK_R * 0.3, 500))
	await _frames(2)
	_check(player.move_dir.length() > 0.05 and player.move_dir.length() < 0.4, "speed ramps from the deadzone (%.2f)" % player.move_dir.length())
	_touch(12, Vector2(270, 500), false)
	# Touchpad: no ring, a short slide walks at full speed, reverses instantly.
	touch.touchpad = true
	_touch(13, Vector2(300, 400), true)
	_drag(13, Vector2(312, 400))
	await _frames(2)
	_check(is_equal_approx(player.move_dir.length(), 1.0) and player.move_dir.x > 0.99, "touchpad: small slide = full speed (%s)" % player.move_dir)
	_drag(13, Vector2(500, 400))
	_drag(13, Vector2(460, 400))
	await _frames(2)
	_check(player.move_dir.x < -0.99, "touchpad: reverses at once (%s)" % player.move_dir)
	await _shot("0_touchpad")
	_touch(13, Vector2(460, 400), false)
	await _frames(2)
	_check(player.move_dir == Vector2.ZERO, "touchpad release stops")
	touch.touchpad = false
	GameSettings.reset()
	_check(GameSettings.move_mode == "joystick", "joystick is the default movement")

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

	# Staff marker (2026-11-28): no fixed staff button while alive; Fireball
	# holds the corner, D sits where Fireball was.
	await _seconds(0.6)
	var corner := touch._button_center("A")
	_check(touch._button_center("Q") == corner and touch._button_at(corner) == "Q", "Fireball is in the corner")
	_check(touch._button_center("D") == corner + Vector2(-170, 0), "D sits at the old Q spot")
	_check(not touch._shown("A"), "no staff button while alive")
	var enemy2 := touch._nearest_enemy()
	for n in get_nodes_in_group("wizards"):
		if n != player and n != enemy2:
			n.global_position = c + Vector2(0, 900) # out of the way
	player.global_position = c
	enemy2.global_position = c + Vector2(110, 0)
	enemy2.knockback = Vector2.ZERO
	player.reset_physics_interpolation()
	await _frames(2)
	_check(touch.marker_targets().is_empty(), "no marker at 110 px")
	enemy2.global_position = c + Vector2(60, 0)
	await _frames(2)
	_check(enemy2 in touch.marker_targets(), "marker over an enemy at 60 px")
	var hp := enemy2.health
	var m_pos: Vector2 = touch.marker_center(enemy2)
	_touch(7, m_pos, true)
	await _frames(2)
	_check(player.attack_target == enemy2 or player.is_casting(), "tapping the marker goes for that warlock")
	await _seconds(0.5)
	_check(enemy2.health < hp, "the marker swing hits (hp %.1f)" % enemy2.health)
	await _shot("5_staff_marker")
	enemy2.global_position = player.global_position + Vector2(24, 0)
	enemy2.knockback = Vector2.ZERO
	await _seconds(0.5)
	_check(player.is_casting() or player.get_spell("A").cooldown_left > 0.0, "holding the marker keeps swinging")
	_touch(7, m_pos, false)
	await _seconds(0.6)

	# A marker on the joystick half is the staff, not the stick.
	player.global_position = c
	enemy2.global_position = c + Vector2(-60, 0)
	enemy2.knockback = Vector2.ZERO
	player.reset_physics_interpolation()
	enemy2.reset_physics_interpolation()
	await _frames(2)
	var left_m: Vector2 = touch.marker_center(enemy2)
	_touch(8, left_m, true)
	await _frames(2)
	_check(left_m.x < root.get_visible_rect().size.x * 0.5 and touch._stick_index == -1,
			"a marker on the left half doesn't grab the stick")
	_touch(8, left_m, false)
	# Walking stops the chase.
	player.attack(enemy2)
	_touch(9, Vector2(250, 500), true)
	_drag(9, Vector2(150, 500))
	await _frames(3)
	_check(player.attack_target == null, "moving the stick stops the staff chase")
	_touch(9, Vector2(150, 500), false)
	await _frames(2)
	# Two enemies in range: two markers. Locked: none.
	var other: Wizard = null
	for n in get_nodes_in_group("wizards"):
		if n != player and n != enemy2:
			other = n
	other.global_position = player.global_position + Vector2(0, 60)
	enemy2.global_position = player.global_position + Vector2(60, 0)
	await _frames(2)
	_check(touch.marker_targets().size() == 2, "a marker over each enemy in range")
	touch.locked = true
	_check(touch.marker_targets().is_empty(), "no markers between rounds")
	touch.locked = false
	other.global_position = c + Vector2(0, 900)
	# The corner is Fireball now: a tap there casts it.
	await _seconds(0.8)
	_touch(10, corner, true)
	_touch(10, corner, false)
	_check(player.get_spell("Q").cooldown_left > 0.0, "tapping the corner casts Fireball")
	await _seconds(0.6)

	# Fireball aiming (v0.7): true-range guide, in-range / on-screen first, lead.
	var q_spell := player.get_spell("Q") as FireballSpell
	_check(touch._reach(q_spell) == q_spell.max_range and q_spell.max_range == 850.0,
			"aim guide shows the real fireball range (%.0f)" % touch._reach(q_spell))
	var blue: Wizard = game.get_node("Wizards/BotBlue")
	var green: Wizard = game.get_node("Wizards/BotGreen")
	var purple: Wizard = game.get_node("Wizards/BotPurple")
	var cam0: ArenaCamera = game.get_node("Arena").camera
	player.global_position = c
	player.knockback = Vector2.ZERO
	player.reset_physics_interpolation()
	cam0.global_position = c
	cam0.reset_smoothing()
	cam0.reset_physics_interpolation()
	blue.global_position = c + Vector2(1200, 0)
	green.global_position = c + Vector2(-1500, 0)
	purple.global_position = c + Vector2(0, 1500)
	await _frames(3)
	_check(touch._auto_target(850.0) == blue, "nobody in range: still aims at the nearest")
	green.global_position = c + Vector2(-600, 0)
	await _frames(2)
	_check(touch._auto_target(850.0) == green, "an enemy in range beats a nearer-to-nothing one")
	var view := root.get_visible_rect().size / cam0.zoom
	blue.global_position = c + Vector2(view.x * 0.4, 0) # on screen
	purple.global_position = c + Vector2(0, view.y * 0.5 + 80.0) # off screen
	if purple.global_position.distance_to(c) > blue.global_position.distance_to(c):
		blue.global_position = c + Vector2(purple.global_position.distance_to(c) - 20.0, 0)
		blue.global_position.x = minf(blue.global_position.x, c.x + view.x * 0.48)
	await _frames(10)
	var xf := root.get_canvas_transform()
	var picked: Wizard = touch._auto_target(850.0)
	_check(picked == blue, "prefers the enemy you can see (picked %s; purple on screen at %s)" % [
			picked.name if picked else "none", xf * purple.global_position])
	blue.velocity = Vector2(0, 165)
	var lead := touch._lead(blue, q_spell.speed)
	var expect := blue.global_position + blue.velocity * (blue.global_position.distance_to(c) / q_spell.speed)
	_check(lead.distance_to(expect) < 1.0 and lead.y > blue.global_position.y + 50.0,
			"fireball tap leads a walking target (%.0f px ahead)" % (lead.y - blue.global_position.y))

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
