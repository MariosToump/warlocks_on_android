extends SceneTree
## GameClock: gameplay timers run on game time (physics frames), so the
## uncapped sim sandbox sees the same windows as the real game.
##   godot --headless --path . -s tools/test_clock.gd

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var t0 := GameClock.now()
	for i in 30:
		await physics_frame
	var dt := GameClock.now() - t0
	_check(absf(dt - 0.5) < 0.001, "30 physics frames = 0.5 s of game time (%.4f)" % dt)
	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1
