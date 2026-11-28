extends SceneTree
## Times the lava edge code alone (headless):
##   godot --headless --path . -s tools/perf_lava.gd
## One full shrink step (6 tiles at 3 tiles/s at 60 fps = 120 calls), the
## per-frame cost of _set_radius, how many cells it repaints, and the
## other per-frame lava helpers the HUD and bots call.

func _init() -> void:
	var arena: Arena = load("res://scenes/arena.tscn").instantiate()
	arena.seed_value = 4
	root.add_child(arena)
	await process_frame
	var dts: Array[float] = []
	var r := arena.radius_tiles
	var target := r - 6.0
	while r > target:
		r = maxf(r - 3.0 / 60.0, target)
		var t0 := Time.get_ticks_usec()
		arena._set_radius(r)
		dts.append((Time.get_ticks_usec() - t0) / 1000.0)
	dts.sort()
	var total := 0.0
	for d in dts:
		total += d
	print("_set_radius: calls=%d avg=%.3fms p50=%.3f max=%.3f total=%.1fms" % [dts.size(), total / dts.size(),
			dts[dts.size() / 2], dts[-1], total])
	var t1 := Time.get_ticks_usec()
	for i in 1000:
		arena.is_lava_soon(arena.get_center() + Vector2(i, 0))
		arena.is_lava_at(arena.get_center() + Vector2(0, i))
	print("1000 is_lava_soon + is_lava_at: %.3fms" % ((Time.get_ticks_usec() - t1) / 1000.0))
	var t2 := Time.get_ticks_usec()
	for i in 100:
		arena._update_ember_points()
	print("_update_ember_points: %.3fms each" % ((Time.get_ticks_usec() - t2) / 100000.0))
	quit()
