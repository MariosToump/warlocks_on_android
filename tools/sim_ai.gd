extends SceneTree
## Bots-only free-for-all for tuning (the player is parked far away).
##   godot --headless --path . -s tools/sim_ai.gd -- <easy|normal|hard> [seconds]
## Prints per bot: casts per spell, deaths, and frames spent walking onto
## lava by itself (on lava while barely knocked back; should be 0).

var game: Node
var bots: Array[Wizard] = []
var stats := {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var diff: String = args[0] if args.size() > 0 else "normal"
	var secs := float(args[1]) if args.size() > 1 else 60.0
	game = load("res://scenes/game.tscn").instantiate()
	game.bot_difficulty = {"easy": 0, "normal": 1, "hard": 2}[diff]
	game.rounds = false # endless, the dead respawn
	game.apply_settings = false
	root.add_child(game)
	_run.call_deferred(diff, secs)


func _run(diff: String, secs: float) -> void:
	await physics_frame
	var player: Wizard = game.get_node("Wizards/Player")
	player.process_mode = Node.PROCESS_MODE_DISABLED # parked, out of the fight
	player.remove_from_group("wizards") # not a target
	player.global_position = game.get_node("Arena").get_center() + Vector2(-1100, 0)
	for n in ["BotBlue", "BotGreen", "BotPurple"]:
		var w: Wizard = game.get_node("Wizards/" + n)
		bots.append(w)
		stats[w] = {"casts": {}, "deaths": 0, "walked_into_lava": 0, "lava_deaths": 0, "lava_time": 0.0, "killed_by": {}}
		w.cast_started.connect(func(slot): stats[w].casts[slot] = stats[w].casts.get(slot, 0) + 1)
		w.died.connect(func(_w):
			stats[w].deaths += 1
			var k: String = String(w.last_attacker.name) if w.last_attacker else "lava"
			stats[w].killed_by[k] = stats[w].killed_by.get(k, 0) + 1
			if w.on_lava or w.arena.is_lava_at(w.global_position):
				stats[w].lava_deaths += 1)
	var t := 0.0
	while t < secs:
		await physics_frame
		t += 1.0 / 60.0
		for w in bots:
			if w.alive and w.on_lava:
				stats[w].lava_time += 1.0 / 60.0
			if w.alive and w.on_lava and w.knockback.length() < 20.0 and not _just_landed(w):
				stats[w].walked_into_lava += 1
	print("=== %s, %.0f s ===" % [diff, secs])
	for w in bots:
		var ai: AIController = w.get_node("AIController")
		print("%-10s %-9s deaths %d (lava %d)  in lava %.1f s  walked onto lava %d frames  killed by %s  casts %s" % [
			w.name, ai.personality.personality_name, stats[w].deaths, stats[w].lava_deaths, stats[w].lava_time,
			stats[w].walked_into_lava, stats[w].killed_by, stats[w].casts])
	quit()


## Knockback below 20 px/s while on lava right after a hit is the tail of the
## push, not the bot walking in. Allow 0.4 s of grace after any hit.
var _last_kb := {}
func _just_landed(w: Wizard) -> bool:
	var now := Time.get_ticks_msec()
	if w.knockback.length() > 1.0 or not _last_kb.has(w):
		_last_kb[w] = now
	return now - _last_kb[w] < 400
