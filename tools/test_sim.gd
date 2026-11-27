extends SceneTree
## Sim sandbox: forced loadouts, no gold / shop, one record per round, kill
## credit on game time.   godot --headless --path . -s tools/test_sim.gd

var failures := 0
const KEYS := ["name", "loadout", "won", "kills", "died", "lava_death", "mood", "casts"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(SimRunner.loadouts(Shop.SPELLS.keys()).size() == 29, "7 spells -> 29 loadouts (none, 7 singles, 21 pairs)")

	print("kill credit on game time")
	var r := _runner("duel", 99)
	await process_frame
	await process_frame
	var g := r.game
	while g.state != g.State.FIGHT:
		await physics_frame
	var ws: Array = g.all_wizards
	var a: Wizard = ws[0]
	var b: Wizard = ws[1]
	var credited := [false]
	g.kill_scored.connect(func(k, v): credited[0] = credited[0] or (k == a and v == b))
	b.take_damage(1.0, a)
	for i in 120: # 2 s of game time
		await physics_frame
	b.take_damage(9999.0, null)
	await physics_frame
	_check(credited[0], "a death 2 s after a hit credits the hitter")
	r.queue_free()
	await process_frame

	for mode in ["duel", "ffa"]:
		print(mode)
		r = _runner(mode, 3)
		await process_frame
		g = r.game
		var n := 2 if mode == "duel" else 4
		_check(g.all_wizards.size() == n, "%d wizards" % n)
		var leak := [false]
		g.fight_started.connect(func():
			for w: Wizard in g.all_wizards:
				var have: Array = []
				for slot in Shop.SHOP_SLOTS:
					var s := w.get_spell(slot)
					if s and not s.is_queued_for_deletion():
						have.append(s.spell_id)
				have.sort()
				var want: Array = r._loadout[w].duplicate()
				want.sort()
				if have != want:
					leak[0] = true
				if g.gold.get(w, 0) != 0 or not w.items.is_empty():
					leak[0] = true)
		var t0 := GameClock.now()
		while r.records.size() < 3 and GameClock.now() - t0 < 700.0:
			await physics_frame
		_check(r.records.size() >= 3, "3 rounds logged")
		_check(not leak[0], "spells = the logged loadout; no gold, no items")
		var ok := true
		for rec in r.records:
			if rec.wizards.size() != n or not rec.has("secs") or not rec.has("timeout"):
				ok = false
			var winners := 0
			for wr in rec.wizards:
				for k in KEYS:
					if not wr.has(k):
						ok = false
				winners += 1 if wr.won else 0
			if winners > 1:
				ok = false
		_check(ok, "records complete, at most one winner")
		r.queue_free()
		await process_frame

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _runner(mode: String, n: int) -> SimRunner:
	var r := SimRunner.new()
	r.mode = mode
	r.rounds = n
	root.add_child(r)
	return r


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1
