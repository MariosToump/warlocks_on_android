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
	game.title_screen = false
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
	_check(_unsafe_matches(), "is_unsafe == is_lava_at or is_lava_soon (warning)")
	_check(arena.status_text() != "", "HUD text while warning: '%s'" % arena.status_text())
	await _until(func(): return arena.radius_tiles <= full - 4.0, 3.0)
	await _frames(2)
	_check(is_equal_approx(arena.radius_tiles, full - 4.0), "shrinks by one step (radius %.1f)" % arena.radius_tiles)
	_check(arena.is_lava_at(doomed), "old edge is lava now")
	_check(not arena.is_lava_at(safe) and not arena.is_lava_at(c), "inner stone stays stone")
	_check(_tiles_match_full_rebuild(), "incremental tile update matches a full rebuild")
	_check(_lava_matches_rule(), "every vertex follows the edge rule (dist > r + wobble)")
	_check(_unsafe_matches(), "is_unsafe == is_lava_at or is_lava_soon (after a shrink)")
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
	_check(_lava_matches_rule(), "regrown vertices follow the edge rule")
	print("perf: one shrink frame touches only the melting vertices")
	var t0 := Time.get_ticks_usec()
	for i in 20:
		arena._set_radius(arena.radius_tiles - 0.05)
	var per_ms := (Time.get_ticks_usec() - t0) / 20000.0
	_check(per_ms < 0.5, "a shrink step costs %.3f ms (was ~1.3 ms before the 2026-11-28 perf pass)" % per_ms)
	_check(_lava_matches_rule(), "edge rule still holds after small steps")
	arena.regrow()

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
	_check(_unsafe_matches(), "is_unsafe == is_lava_at or is_lava_soon (sudden death)")
	_check(saw_final and arena.radius_tiles == 0.0, "after the hold the edge creeps in to nothing (r %.1f)" % arena.radius_tiles)
	_check(arena.is_lava_at(c), "even the middle is lava in the end")
	_check(_tiles_match_full_rebuild(), "tiles correct after sudden death")
	_check(_lava_matches_rule(), "sudden death vertices follow the edge rule")
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
		before[cell] = [arena.tiles.get_cell_source_id(cell), arena.tiles.get_cell_atlas_coords(cell),
				arena.tiles.get_cell_alternative_tile(cell)]
	arena.rebuild()
	var cells := arena.tiles.get_used_cells()
	if cells.size() != before.size():
		return false
	for cell in cells:
		if before.get(cell) != [arena.tiles.get_cell_source_id(cell), arena.tiles.get_cell_atlas_coords(cell),
				arena.tiles.get_cell_alternative_tile(cell)]:
			return false
	return true


## The old brute-force rule: lava where the full map has lava, or where the
## vertex is further from the centre than radius + wobble.
func _lava_matches_rule() -> bool:
	var center := Vector2(arena.map_cells, arena.map_cells) / 2.0
	var r := arena.radius_tiles
	for row in arena.map_cells + 1:
		for col in arena.map_cells + 1:
			var d := Vector2(col, row) - center
			var key := d.length() - arena._wobble(d.angle())
			if absf(key - r) < 1e-6:
				continue # a tie: either answer is right
			var want := arena._full_vertices[row][col] == Arena.Terrain.LAVA or r <= 0.0 or key > r
			if (arena.vertices[row][col] == Arena.Terrain.LAVA) != want:
				return false
	return true


## The bots' merged check gives the same answer as the two old ones, on a
## grid of points over the whole map plus random off-grid points.
func _unsafe_matches() -> bool:
	var b := arena.get_bounds().grow(64.0)
	for i in 4000:
		var p := Vector2(randf_range(b.position.x, b.end.x), randf_range(b.position.y, b.end.y))
		if arena.is_unsafe(p) != (arena.is_lava_at(p) or arena.is_lava_soon(p)):
			return false
	for x in range(int(b.position.x), int(b.end.x), 23):
		for y in range(int(b.position.y), int(b.end.y), 23):
			var p := Vector2(x, y)
			if arena.is_unsafe(p) != (arena.is_lava_at(p) or arena.is_lava_soon(p)):
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
