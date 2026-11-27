extends SceneTree
## Visual pass 1: hit sparks, cast puffs, squash/stretch, death dissolve,
## lava embers, heat shimmer, shadows. Bots are passive dummies.
##   godot --headless --path . -s tools/test_vfx.gd

var game: Node
var player: Wizard
var blue: Wizard
var failures := 0


func _init() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.bot_ai = false
	game.shrink_arena = false
	game.apply_settings = false
	game.title_screen = false
	game.countdown_time = 0.1
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _seconds(0.3)
	player = game.player
	blue = game.get_node("Wizards/BotBlue")

	print("hit sparks")
	blue.global_position = player.global_position + Vector2(140, 0)
	blue.cast("Q", player.global_position)
	var seen_fire := false
	for i in 90:
		await physics_frame
		if Vfx.last_hit_kind == "fire":
			seen_fire = true
			break
	_check(seen_fire, "a fireball hit makes fire sparks")
	_check(Vfx.live_count(self) >= 1, "a spark burst is alive (%d)" % Vfx.live_count(self))
	for i in 40:
		Vfx.burst(game, player.global_position, Color.WHITE)
	_check(Vfx.live_count(self) <= Vfx.MAX_LIVE, "the burst cap holds (%d)" % Vfx.live_count(self))
	await _seconds(0.9)
	_check(Vfx.live_count(self) == 0, "bursts free themselves (%d left)" % Vfx.live_count(self))
	player.flash_hit(Vector2.RIGHT, "lightning")
	_check(Vfx.last_hit_kind == "lightning", "flash_hit passes its kind")
	await physics_frame
	_check(player.sprite.scale.x > 1.0, "a hit squashes the sprite (%s)" % player.sprite.scale)
	await _seconds(0.4)
	_check(player.sprite.scale == Vector2.ONE, "and it springs back")

	print("cast puff + stretch")
	Vfx.last_cast_id = ""
	player.cast("Q", player.global_position + Vector2(0, 200))
	var stretched := false
	for i in 40:
		await physics_frame
		if player.sprite.scale.y > 1.0:
			stretched = true
	_check(Vfx.last_cast_id == "Q", "releasing a spell makes a puff (%s)" % Vfx.last_cast_id)
	_check(stretched, "the sprite stretches on the cast")
	await _seconds(0.4)
	_check(player.sprite.scale == Vector2.ONE, "and settles back")

	print("death dissolve")
	var green: Wizard = game.get_node("Wizards/BotGreen")
	var mat := green.sprite.material as ShaderMaterial
	_check(mat.get_shader_parameter("dissolve") == 0.0, "alive: no dissolve")
	green.take_damage(500)
	await physics_frame
	_check(Vfx.live_count(self) >= 1, "death embers")
	await _seconds(1.6)
	_check(mat.get_shader_parameter("dissolve") >= 0.99, "dissolved (%.2f)" % mat.get_shader_parameter("dissolve"))
	_check(not green.visible, "then hidden")
	green.reset(green.global_position)
	_check(mat.get_shader_parameter("dissolve") == 0.0 and green.visible and green.modulate == Color.WHITE,
		"reset: whole again")

	print("lava embers")
	var arena: Arena = game.arena
	_check(arena.embers != null and arena.embers.emitting and arena.embers.amount == 40, "embers rise off the lava")
	_check(_embers_ok(arena), "every ember spot is lava near the edge")
	arena._set_radius(arena.min_radius_tiles)
	_check(_embers_ok(arena), "still on lava after a shrink")
	arena._set_radius(0.0)
	_check(arena.embers.emission_points.size() > 0, "and when the island is gone")
	arena.regrow()

	print("heat shimmer")
	_check(arena.heat_haze != null and arena.heat_haze.visible, "shimmer over the lava by default")
	arena.set_heat_haze(false)
	_check(not arena.heat_haze.visible and arena.heat_haze.process_mode == Node.PROCESS_MODE_DISABLED,
		"turned off: hidden and not running")
	arena.set_heat_haze(true)
	GameSettings.path = "user://test_vfx_settings.cfg"
	GameSettings.heat_haze = false
	GameSettings.save_settings()
	GameSettings.heat_haze = true
	GameSettings.load_settings()
	_check(not GameSettings.heat_haze, "the setting is saved")
	GameSettings.reset()
	_check(GameSettings.heat_haze, "and defaults to on")
	game.pause_menu._toggle_heat_haze()
	_check(not arena.heat_haze.visible, "the pause menu toggle turns it off in the match")
	GameSettings.reset()
	GameSettings.save_settings()

	print("shadows")
	_check(Wizard.SHADOW.x > Wizard.SHADOW.y and Wizard.SHADOW.y > 0.0, "wizards have a flat shadow")
	var orb: Projectile = load("res://scenes/projectile_fireball.tscn").instantiate()
	_check(orb.draws_shadow, "projectiles draw a shadow")
	orb.free()

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _embers_ok(arena: Arena) -> bool:
	var pts := arena.embers.emission_points
	if pts.is_empty():
		return false
	for p in pts:
		var world := arena.embers.to_global(p)
		var from_edge := arena._tiles_from_center(world) - arena._edge_at(world, arena.radius_tiles)
		if not arena.is_lava_at(world) or from_edge > 6.0:
			return false
	return true


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _seconds(s: float) -> void:
	await create_timer(s).timeout
