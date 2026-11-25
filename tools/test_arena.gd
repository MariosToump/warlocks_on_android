extends SceneTree
## Shrinking arena tests.
##   godot --headless --path . -s tools/test_arena.gd

var game: Node
var arena: Arena
var c: Vector2
var failures := 0


func _init() -> void:
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
	c = arena.get_center()
	game.get_node("Wizards/Player/PlayerController").process_mode = Node.PROCESS_MODE_DISABLED
	var full := arena.platform_radius_tiles

	print("off by default in tests")
	await _seconds(0.5)
	_check(arena.radius_tiles == full, "no shrinking while shrinks is off")

	print("warning, then shrink")
	arena.shrink_delay = 1.0
	arena.shrink_warning = 0.6
	arena.shrink_step_tiles = 4.0
	arena.shrink_speed = 40.0
	arena.min_radius_tiles = full - 12.0
	arena.min_hold = 1.0
	arena.shrinks = true
	arena.restart_shrink_timer()
	var doomed := _east(full - 2.0)
	var safe := _east(full - 8.0)
	await _seconds(0.2)
	_check(not arena.is_lava_soon(doomed), "no warning long before the shrink")
	await _seconds(0.5)
	_check(arena.is_lava_soon(doomed) and not arena.is_lava_at(doomed), "edge ring is flagged before it turns to lava")
	_check(not arena.is_lava_soon(safe) and not arena.is_lava_soon(c), "inner stone is not flagged")
	_check(arena.status_text() != "", "HUD text while warning: '%s'" % arena.status_text())
	await _until(func(): return arena.radius_tiles <= full - 4.0, 3.0)
	await _frames(2)
	_check(is_equal_approx(arena.radius_tiles, full - 4.0), "shrinks by one step (radius %.1f)" % arena.radius_tiles)
	_check(arena.is_lava_at(doomed), "old edge is lava now")
	_check(not arena.is_lava_at(safe) and not arena.is_lava_at(c), "inner stone stays stone")
	_check(_tiles_match_full_rebuild(), "incremental tile update matches a full rebuild")
	_check(_cracks_away_from_lava(), "cracked stone never touches lava")

	print("stops at the minimum, then regrows")
	var lowest := full
	var t := 0.0
	while t < 8.0 and arena.radius_tiles < full - 0.01 or t < 0.1:
		await _frames(1)
		t += 1.0 / 60.0
		lowest = minf(lowest, arena.radius_tiles)
	_check(is_equal_approx(lowest, full - 12.0), "never below the minimum (lowest %.1f)" % lowest)
	await _frames(2)
	_check(is_equal_approx(arena.radius_tiles, full) and not arena.is_lava_at(doomed), "platform regrows after holding at the minimum")
	_check(_tiles_match_full_rebuild(), "tiles correct after regrowing")

	print("sudden death (rounds: no regrowing)")
	arena.regrows = false
	arena.final_shrink_speed = 30.0
	arena.restart_shrink_timer()
	var saw_final := false
	var hold_text := ""
	t = 0.0
	while t < 10.0 and arena.radius_tiles > 0.0:
		await _frames(1)
		t += 1.0 / 60.0
		saw_final = saw_final or arena.phase == Arena.Phase.FINAL
		if arena.phase == Arena.Phase.HOLD:
			hold_text = arena.status_text()
	_check(hold_text.begins_with("Sudden death in"), "warns while holding ('%s')" % hold_text)
	_check(saw_final and arena.radius_tiles == 0.0, "after the hold the edge creeps in to nothing (r %.1f)" % arena.radius_tiles)
	_check(arena.is_lava_at(c), "even the middle is lava in the end")
	_check(_tiles_match_full_rebuild(), "tiles correct after sudden death")
	arena.regrows = true
	arena.regrow()

	print("random stone point")
	arena.shrinks = false
	var ok := true
	for i in 50:
		var p := arena.random_stone_point()
		if arena.is_lava_at(p) or arena.is_lava_soon(p) or p.distance_to(c) > arena.radius_tiles * arena.tile_size:
			ok = false
	_check(ok, "random_stone_point is always safe stone inside the platform")

	print("respawn inside a shrunk platform")
	arena.shrinks = true
	arena.min_hold = 100.0
	arena.restart_shrink_timer()
	await _until(func(): return arena.radius_tiles <= full - 12.0, 15.0)
	var blue: Wizard = game.get_node("Wizards/BotBlue")
	game.respawn_delay = 0.2
	blue.global_position = _east(full + 3.0) # old spawn would be fine; kill it anyway
	blue.take_damage(1000.0)
	await _seconds(0.6)
	_check(blue.alive and not arena.is_lava_at(blue.global_position)
		and blue.global_position.distance_to(c) < arena.radius_tiles * arena.tile_size,
		"respawns on stone inside the current platform")

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _east(tiles: float) -> Vector2:
	return c + Vector2(tiles * arena.tile_size, 0)


func _tiles_match_full_rebuild() -> bool:
	var before := {}
	for cell in arena.tiles.get_used_cells():
		before[cell] = [arena.tiles.get_cell_source_id(cell), arena.tiles.get_cell_atlas_coords(cell)]
	arena.rebuild()
	var cells := arena.tiles.get_used_cells()
	if cells.size() != before.size():
		return false
	for cell in cells:
		if before.get(cell) != [arena.tiles.get_cell_source_id(cell), arena.tiles.get_cell_atlas_coords(cell)]:
			return false
	return true


func _cracks_away_from_lava() -> bool:
	for r in range(1, arena.map_cells):
		for col in range(1, arena.map_cells):
			if arena.vertices[r][col] != Arena.Terrain.CRACKED:
				continue
			for dr in [-1, 0, 1]:
				for dc in [-1, 0, 1]:
					if arena.vertices[r + dr][col + dc] == Arena.Terrain.LAVA:
						return false
	return true


func _until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while t < limit and not cond.call():
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
