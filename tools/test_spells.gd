extends SceneTree
## Milestone 4 test: Blink, Lightning, Shield, plus hurt/death animations.
##   godot --path . -s tools/test_spells.gd -- <screenshot_dir>

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
	game.shrink_arena = false
	game.rounds = false
	game.apply_settings = false
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(5)
	arena = game.get_node("Arena")
	player = game.get_node("Wizards/Player")
	blue = game.get_node("Wizards/BotBlue")
	green = game.get_node("Wizards/BotGreen")
	var c := arena.get_center()
	_check(player.get_spell("W") is BlinkSpell, "W is Blink")
	_check(player.get_spell("E") is LightningSpell, "E is Lightning")
	_check(player.get_spell("R") is ShieldSpell, "R is Shield")
	for s in ["Q", "W", "E", "R"]:
		_check(player.get_spell(s).icon != null, "%s has an icon" % s)

	# --- Blink ---------------------------------------------------------------
	_place(player, c)
	_place(blue, c + Vector2(0, 150))
	_place(green, c + Vector2(0, -150))
	player.knockback = Vector2(300, 0)
	_check(player.cast("W", c + Vector2(-400, 0)), "cast blink")
	await _seconds(0.1)
	await _shot("1_blink", true)
	var moved := player.global_position.distance_to(c)
	_check(moved > 180.0 and moved < 215.0, "blinked ~200 px (%.0f)" % moved)
	_check(player.global_position.x < c.x, "blinked toward the mouse")
	_check(player.knockback == Vector2.ZERO, "blink cancels knockback")
	_check(player.get_spell("W").cooldown_left > 5.5, "blink cooldown 6 s")
	await _seconds(0.3)

	# --- Lightning ---------------------------------------------------------
	_place(player, c)
	_place(blue, c + Vector2(130, 0))
	_place(green, c + Vector2(400, 0)) # behind blue and out of range
	await _frames(2)
	_check(player.cast("E", blue.global_position), "cast lightning")
	await _seconds(0.17)
	await _shot("2_lightning", true)
	_check(is_equal_approx(blue.health, 92.0), "lightning hits for 8 (hp %.1f)" % blue.health)
	_check(blue.knockback.length() > 500.0, "high knockback (%.0f)" % blue.knockback.length())
	_check(blue.sprite.animation.begins_with("hurt"), "hurt animation plays (%s)" % blue.sprite.animation)
	_check(blue.sprite.flip_h, "hit from the west -> faces west (mirrored)")
	_check(is_equal_approx(green.health, 100.0), "only the first wizard is hit")
	await _seconds(1.2)
	var pushed := blue.global_position.x - (c.x + 130.0)
	_check(pushed > 140.0, "lightning pushes further than a fireball (%.0f px)" % pushed)

	# Lightning out of range.
	_place(blue, c + Vector2(300, 0))
	var hp := blue.health
	player.get_spell("E").cooldown_left = 0.0
	player.cast("E", blue.global_position)
	await _seconds(0.3)
	_check(is_equal_approx(blue.health, hp), "out of range (300 px) misses")

	# --- Shield ------------------------------------------------------------
	_place(player, c)
	_place(blue, c + Vector2(120, 0))
	await _seconds(0.3)
	player.get_spell("E").cooldown_left = 0.0
	blue.raise_shield(1.5)
	hp = blue.health
	player.cast("E", blue.global_position)
	await _seconds(0.2)
	_check(is_equal_approx(blue.health, hp) and blue.knockback == Vector2.ZERO, "shield blocks lightning")
	await _shot("3_shield_block", true)
	await _seconds(1.5)
	_check(not blue.is_shielded() and not blue.bubble.visible, "shield ends after 1.5 s")

	# Shield reflects a fireball back at its caster.
	_place(player, c)
	_place(green, c + Vector2(0, -160))
	await _frames(2)
	_check(green.cast("R", c), "dummy casts shield")
	await _seconds(0.15)
	_check(green.is_shielded(), "shield up")
	var php := player.health
	player.get_spell("Q").cooldown_left = 0.0
	player.cast("Q", green.global_position)
	var t0 := Time.get_ticks_msec()
	var reflected := false
	while Time.get_ticks_msec() - t0 < 1500 and player.health >= php:
		var p := _find_projectile()
		if p and p.caster == green:
			reflected = true
		await _frames(1)
	_check(reflected, "fireball reflected (now owned by the shielded wizard)")
	_check(is_equal_approx(green.health, 100.0), "shielded wizard not hurt")
	_check(player.health < php, "caster hit by own reflected fireball (hp %.1f)" % player.health)
	await _frames(2)
	await _shot("4_reflected")

	# --- Death animation ---------------------------------------------------
	await _seconds(0.6)
	_place(blue, c + Vector2(-120, 60))
	blue.face(blue.global_position + Vector2(10, 0))
	blue.take_damage(1000.0)
	await _frames(3)
	_check(blue.sprite.animation.begins_with("death"), "death animation plays (%s)" % blue.sprite.animation)
	await _seconds(0.3)
	await _shot("5_death")

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _place(w: Wizard, at: Vector2) -> void:
	if not w.alive:
		w.reset(at)
	w.global_position = at
	w.knockback = Vector2.ZERO
	w.move_target = null


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


func _shot(name: String, zoom := false) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	var img := root.get_texture().get_image()
	img.save_png("%s/m4_%s.png" % [out_dir, name])
	if zoom:
		var p := Vector2i(player.get_global_transform_with_canvas().origin)
		var r := Rect2i(p - Vector2i(160, 110), Vector2i(400, 200)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var crop := img.get_region(r)
		crop.resize(r.size.x * 3, r.size.y * 3, Image.INTERPOLATE_NEAREST)
		crop.save_png("%s/m4_%s_zoom.png" % [out_dir, name])
