extends SceneTree
## Staff auto-attack test, plus the speed / crisp-pixel changes.
##   godot --path . -s tools/test_staff.gd -- <screenshot_dir>

var game: Node
var player: Wizard
var blue: Wizard
var green: Wizard
var arena: Arena
var out_dir := ""
var failures := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ""
	game = load("res://scenes/game.tscn").instantiate()
	game.bot_ai = false
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(5)
	arena = game.get_node("Arena")
	player = game.get_node("Wizards/Player")
	blue = game.get_node("Wizards/BotBlue")
	green = game.get_node("Wizards/BotGreen")
	var c := arena.get_center()
	var staff := player.get_spell("A") as StaffStrikeSpell
	_check(staff != null and staff.icon != null, "A is the staff strike, with an icon")
	_check(player.get_spell("Q") is FireballSpell, "Q is still Fireball")

	# Crisp pixels: one art pixel = a whole number of screen pixels.
	var cam: ArenaCamera = arena.camera
	var px := cam.zoom.x * cam.screen_scale()
	_check(is_equal_approx(px, roundf(px)), "art pixel = %.2f screen px (whole)" % px)
	_check(ProjectSettings.get_setting("physics/common/physics_interpolation"), "physics interpolation on")

	# Faster movement and fireball.
	_check(player.move_speed >= 160.0, "move speed %.0f" % player.move_speed)
	_check((player.get_spell("Q") as FireballSpell).speed >= 540.0, "fireball speed up")

	# Attack animation length = cooldown = cast time.
	var frames := player.sprite.sprite_frames
	for d in ["south", "east", "north"]:
		var a: String = "attack_" + d
		_check(frames.has_animation(a), a + " exists")
		var length := frames.get_frame_count(a) / frames.get_animation_speed(a)
		_check(absf(length - staff.cooldown()) < 0.06, "%s lasts %.2f s ~ cooldown %.2f" % [a, length, staff.cooldown()])

	# --- Single swing in reach --------------------------------------------
	_place(player, c)
	_place(blue, c + Vector2(26, 0))
	_place(green, c + Vector2(-300, 0))
	await _frames(2)
	_check(player.cast("A", blue.global_position), "swing")
	_check(player.sprite.animation == &"attack_east", "attack_east anim (%s)" % player.sprite.animation)
	await _seconds(0.28)
	await _shot("1_swing")
	_check(is_equal_approx(blue.health, 96.0), "staff hits for 4 (hp %.1f)" % blue.health)
	_check(blue.knockback.x > 200.0, "shoves the target away (%.0f)" % blue.knockback.x)
	_check(not player.get_spell("A").is_ready(), "on cooldown")
	await _seconds(0.3)
	_check(player.get_spell("A").is_ready(), "ready again after the swing (~0.5 s)")

	# Out of reach: a swing at air hits nothing.
	_place(blue, c + Vector2(80, 0))
	blue.health = 100.0
	await _frames(2)
	player.cast("A", blue.global_position)
	await _seconds(0.55)
	_check(is_equal_approx(blue.health, 100.0), "no hit out of reach")

	# --- Auto-attack: chases and keeps swinging ---------------------------
	_place(player, c)
	_place(blue, c + Vector2(0, 120))
	blue.reset(c + Vector2(0, 120))
	player.attack(blue)
	await _seconds(0.35)
	_check(player.global_position.y > c.y + 30.0, "walks toward the target")
	await _seconds(1.6)
	await _shot("2_auto")
	_check(blue.health <= 92.0, "auto-attack hit more than once (hp %.1f)" % blue.health)
	_check(player.attack_target == blue, "still attacking")

	# Moving cancels the auto-attack.
	player.attack(null)
	player.move_target = player.global_position + Vector2(-100, 0)
	await _seconds(0.3)
	_check(player.attack_target == null and not player.is_casting(), "moving stops attacking")

	# Single tap: one swing, then stop.
	_place(player, c)
	blue.reset(c + Vector2(24, 0))
	await _frames(2)
	player.attack(blue, true)
	await _seconds(1.2)
	_check(is_equal_approx(blue.health, 96.0), "attack once = one hit (hp %.1f)" % blue.health)
	_check(player.attack_target == null, "then stops")

	# Shield blocks the staff and bounces the attacker back.
	_place(player, c)
	blue.reset(c + Vector2(26, 0))
	await _frames(2)
	blue.raise_shield(2.0)
	player.cast("A", blue.global_position)
	await _seconds(0.3)
	_check(is_equal_approx(blue.health, 100.0), "shield blocks the staff")
	_check(player.knockback.x < -50.0, "attacker bounces off (%.0f)" % player.knockback.x)

	# Fireball flies faster: ~560 px/s.
	_place(player, c)
	_place(blue, c + Vector2(0, 400))
	_place(green, c + Vector2(0, -400))
	await _seconds(0.6)
	player.cast("Q", c + Vector2(500, 0))
	await _seconds(0.25)
	var p := _find_projectile()
	var x0 := p.global_position.x if p else 0.0
	await _seconds(0.5)
	var v := (p.global_position.x - x0) / 0.5 if p and is_instance_valid(p) else 0.0
	_check(v > 500.0 and v < 620.0, "fireball ~560 px/s (%.0f)" % v)

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _place(w: Wizard, at: Vector2) -> void:
	if not w.alive:
		w.reset(at)
	w.global_position = at
	w.knockback = Vector2.ZERO
	w.move_target = null
	w.attack(null)
	w.shield_left = 0.0


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
	var img := root.get_texture().get_image()
	img.save_png("%s/st_%s.png" % [out_dir, name])
	var p := Vector2i(player.get_global_transform_with_canvas().origin)
	var r := Rect2i(p - Vector2i(120, 90), Vector2i(240, 140)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(r)
	crop.resize(r.size.x * 3, r.size.y * 3, Image.INTERPOLATE_NEAREST)
	crop.save_png("%s/st_%s_zoom.png" % [out_dir, name])
