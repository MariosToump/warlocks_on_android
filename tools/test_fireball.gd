extends SceneTree
## Milestone 3 test: fireball casting, hits, knockback, cooldown.
##   godot --path . -s tools/test_fireball.gd -- <screenshot_dir>

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
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(5)
	arena = game.get_node("Arena")
	player = game.get_node("Wizards/Player")
	blue = game.get_node("Wizards/BotBlue")
	green = game.get_node("Wizards/BotGreen")
	_check(player.get_spell("Q") is FireballSpell, "player has Fireball in Q")
	_check(blue.team_color == Wizard.TeamColor.BLUE, "blue dummy spawned")
	await _shot("1_start")

	# Cast at the blue dummy.
	var start_blue := blue.global_position
	_check(player.cast("Q", blue.global_position), "cast Q succeeds")
	_check(not player.cast("Q", blue.global_position), "second cast blocked while casting/cooldown")
	_check(player.is_casting(), "is casting")
	var q: Spell = player.get_spell("Q")
	_check(q.cooldown_left > 1.9, "cooldown started (%.2f)" % q.cooldown_left)
	await _seconds(0.12)
	await _shot("1b_casting", true)
	await _seconds(0.15)
	var fb := _find_projectile()
	_check(fb != null, "fireball spawned at release time")
	await _shot("2_flying")

	# Wait for the hit.
	var t0 := Time.get_ticks_msec()
	while blue.health >= 100.0 and Time.get_ticks_msec() - t0 < 2000:
		await _frames(1)
	_check(is_equal_approx(blue.health, 94.0), "hit for 6 damage (hp %.1f)" % blue.health)
	_check(blue.knockback.length() > 200.0, "knockback applied (%.0f)" % blue.knockback.length())
	await _frames(2)
	await _shot("3_impact")
	await _seconds(1.5)
	var pushed := blue.global_position.distance_to(start_blue)
	_check(pushed > 90.0 and pushed < 170.0, "pushed ~127 px (%.0f)" % pushed)
	var dir := (blue.global_position - start_blue).normalized()
	var aim := (start_blue - player.global_position).normalized()
	_check(dir.dot(aim) > 0.95, "pushed along the fireball's path")

	# Cooldown: ready again after 2 s.
	await _seconds(q.cooldown_left + 0.05)
	_check(q.is_ready(), "cooldown finished")

	# Damage taken scales knockback: hit green (fresh) vs green after damage.
	green.damage_taken = 0.0
	green.knockback = Vector2.ZERO
	green.apply_knockback(Vector2(380, 0))
	var fresh := green.knockback.length()
	green.knockback = Vector2.ZERO
	green.damage_taken = 60.0
	green.apply_knockback(Vector2(380, 0))
	_check(green.knockback.length() > fresh * 1.5, "damaged wizards fly further (%.0f vs %.0f)" % [green.knockback.length(), fresh])
	green.knockback = Vector2.ZERO
	green.damage_taken = 0.0

	# Knock a dummy into the lava: place it near the edge, fire outward.
	var edge := _edge_point(Vector2.DOWN)
	blue.global_position = edge - Vector2(0, 60)
	blue.knockback = Vector2.ZERO
	blue.damage_taken = 80.0 # heavily damaged = flies far
	player.global_position = blue.global_position - Vector2(0, 120)
	await _frames(2)
	player.cast("Q", blue.global_position)
	t0 = Time.get_ticks_msec()
	while not blue.on_lava and Time.get_ticks_msec() - t0 < 3000:
		await _frames(1)
	_check(blue.on_lava, "knocked into lava")
	await _seconds(0.4)
	await _shot("4_into_lava")

	# Projectile range: fire into empty space, it fizzles.
	await _seconds(2.1)
	player.global_position = arena.get_center()
	player.cast("Q", player.global_position + Vector2(-500, 0))
	await _seconds(0.3)
	_check(_find_projectile() != null, "fireball in flight")
	await _seconds(1.8)
	_check(_find_projectile() == null, "fireball expires after max range")

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _find_projectile() -> Projectile:
	for c in game.get_node("Wizards").get_children():
		if c is Projectile and not c.is_queued_for_deletion():
			return c
	return null


func _edge_point(dir: Vector2) -> Vector2:
	var c := arena.get_center()
	for d in range(0, 3000, 8):
		if arena.is_lava_at(c + dir * d):
			return c + dir * d
	return c


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
	if not zoom:
		await _frames(2)
	var img := root.get_texture().get_image()
	img.save_png("%s/m3_%s.png" % [out_dir, name])
	if zoom:
		var p := Vector2i(player.get_global_transform_with_canvas().origin)
		var crop := img.get_region(Rect2i(p - Vector2i(80, 90), Vector2i(160, 120)))
		crop.resize(640, 480, Image.INTERPOLATE_NEAREST)
		crop.save_png("%s/m3_%s_zoom.png" % [out_dir, name])
