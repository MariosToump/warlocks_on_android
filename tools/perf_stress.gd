extends SceneTree
## Performance stress run on the PC (the phone starts the same run from the
## title screen: tap the version label 5 times). See scripts/perf_stress.gd.
##   godot --path . -s tools/perf_stress.gd -- [passes=4,8] [seconds=90] [haze=on|off] [vsync=on|off]
## Headless with --fixed-fps 60 it measures the game logic alone (one physics
## tick per frame, no drawing).


func _init() -> void:
	var a := {}
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=")
		if kv.size() == 2:
			a[kv[0]] = kv[1]
	if a.get("vsync", "on") == "off":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var passes: Array[int] = []
	for p in str(a.get("passes", "4,8")).split(","):
		passes.append(int(p))
	PerfStress.launch(self, passes, float(a.get("seconds", "90")), a.get("haze", "on") == "on", true)
