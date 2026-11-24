extends SceneTree
## Smoke test for milestone 2. Run (not headless, to get screenshots):
##   godot --path . -s tools/test_wizard.gd -- <screenshot_dir>
## Walks the player to the lava edge, checks speed, burning, death, respawn.

var game: Node
var player: Wizard
var arena: Arena
var out_dir := ""
var failures := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ""
	game = load("res://scenes/game.tscn").instantiate()
	game.bot_ai = false
	game.shrink_arena = false
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(5)
	player = game.get_node("Wizards/Player")
	arena = game.get_node("Arena")
	var start := player.global_position
	_check(not arena.is_lava_at(start), "spawns on stone")
	_check(is_equal_approx(player.health, 100.0), "starts with 100 HP")
	await _shot("1_spawn")

	# Walk east for 1 s: speed ~165 px/s, walk animation, facing east.
	player.move_target = start + Vector2(1000, 0)
	await _seconds(1.0)
	var moved := player.global_position.x - start.x
	_check(moved > 145 and moved < 185, "moves ~165 px/s (moved %.0f)" % moved)
	_check(player.sprite.animation == &"walk_east", "walk_east anim (%s)" % player.sprite.animation)
	await _shot("2_walking")

	# Walk west: mirrored sprite.
	player.move_target = player.global_position + Vector2(-200, 0)
	await _seconds(0.3)
	_check(player.sprite.flip_h and player.sprite.animation == &"walk_east", "west = flipped east")

	# Walk straight off the platform into the lava.
	var edge := _find_lava_point()
	player.move_target = edge
	var t0 := Time.get_ticks_msec()
	while not player.on_lava and Time.get_ticks_msec() - t0 < 15000:
		await _frames(1)
	print("  (reached lava after %.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	_check(player.on_lava, "reaches lava")
	_check(player.smoke.emitting and player.glow.enabled, "smoke + glow on lava")
	_check(player.sprite.animation.begins_with("idle") or player.sprite.animation.begins_with("walk"), "anim ok")
	var hp := player.health
	await _seconds(1.0)
	var burned := hp - player.health
	_check(burned > 6.5 and burned < 9.5, "burns ~8 HP/s (%.1f)" % burned)
	await _shot("3_burning")

	# Knockback scales with damage taken.
	player.damage_taken = 50.0
	player.knockback = Vector2.ZERO
	player.apply_knockback(Vector2(100, 0))
	_check(is_equal_approx(player.knockback.x, 150.0), "knockback x1.5 at 50 dmg (%.0f)" % player.knockback.x)
	player.knockback = Vector2.ZERO

	# Stay until dead, then respawn.
	player.take_damage(player.health - 1.0)
	await _seconds(0.5)
	_check(not player.alive, "dies at 0 HP")
	await _seconds(2.5)
	_check(player.alive and is_equal_approx(player.health, 100.0), "respawns with full HP")
	_check(not arena.is_lava_at(player.global_position), "respawns on stone")

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _find_lava_point() -> Vector2:
	var c := arena.get_center()
	for d in range(0, 3000, 16):
		var p := c + Vector2(0, d)
		if arena.is_lava_at(p):
			return p + Vector2(0, 48)
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


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await _frames(3)
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])
	# 4x crop around the player, to judge the sprite and effects.
	var p := Vector2i(player.get_global_transform_with_canvas().origin)
	var crop := img.get_region(Rect2i(p - Vector2i(80, 110), Vector2i(160, 140)))
	crop.resize(640, 560, Image.INTERPOLATE_NEAREST)
	crop.save_png("%s/%s_zoom.png" % [out_dir, name])
