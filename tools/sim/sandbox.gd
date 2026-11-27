extends SceneTree
## Sim sandbox entry (Claude only; not in the APK). One worker:
##   godot --headless --fixed-fps 60 --path . -s tools/sim/sandbox.gd -- mode=ffa rounds=500 seed=7 out=tools/sim/out/ffa/w7.jsonl
## Scenario: mode=scenario file=tools/sim/scenarios/<name>.json seed=1 out=...
## tools/sim/run.py starts many of these in parallel and merges the results.


func _init() -> void:
	var opts := {"mode": "ffa", "rounds": "10", "seed": "1", "out": "", "file": ""}
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			opts[a.get_slice("=", 0)] = a.get_slice("=", 1)
	seed(int(opts.seed))
	var r := SimRunner.new()
	r.mode = opts.mode
	r.rounds = int(opts.rounds)
	r.out_path = opts.out
	r.scenario_file = opts.file
	r.finished.connect(func():
		print("SIM DONE %d records" % r.records.size())
		quit(0))
	root.add_child.call_deferred(r)
