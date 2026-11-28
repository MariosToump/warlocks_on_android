extends SceneTree
## Windowed (not headless): frame time with the lava edge creeping in vs the
## same view standing still, nothing else on screen. Run with vsync off:
##   godot --path . --resolution 1280x720 -s tools/perf_lava_render.gd
## Prints average / max wall-clock frame time and the time of the regrow frame.

var arena: Arena
var _last := 0
var _times: Array[float] = []
var _mode := "still"
var _r := 0.0
var _n := 0

func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	arena = load("res://scenes/arena.tscn").instantiate()
	arena.seed_value = 4
	root.add_child(arena)
	_go.call_deferred()


func _go() -> void:
	arena.camera.global_position = arena.get_center() + Vector2(arena.radius_tiles * arena.tile_size, 0)
	_r = arena.radius_tiles
	_last = Time.get_ticks_usec()
	process_frame.connect(_tick)


func _tick() -> void:
	var now := Time.get_ticks_usec()
	var dt := (now - _last) / 1000.0
	_last = now
	_n += 1
	if _n < 30:
		return
	_times.append(dt)
	if _mode == "shrink":
		_r -= 3.0 / 60.0
		arena._set_radius(_r)
	if _times.size() == 240:
		_print()
		_times.clear()
		if _mode == "still":
			_mode = "shrink"
		elif _mode == "shrink":
			_mode = "regrow"
			var t0 := Time.get_ticks_usec()
			arena.regrow()
			print("regrow() call: %.2fms" % ((Time.get_ticks_usec() - t0) / 1000.0))
		else:
			quit()


func _print() -> void:
	var s := _times.duplicate()
	s.sort()
	var tot := 0.0
	for x in s:
		tot += x
	print("%-7s avg=%.2fms p95=%.2f max=%.2f first=%.2f" % [_mode, tot / s.size(), s[int(s.size() * 0.95)], s[-1], _times[0]])
