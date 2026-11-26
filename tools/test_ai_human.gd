extends SceneTree
## Smarter-bot tests (v0.10): weighted choice, human noise, moods, the opening
## watch, the memory of seen casts, opportunity and the personalities.
##   godot --headless --path . -s tools/test_ai_human.gd
## Same setup as test_ai.gd: passive bots, each test gives one an AIController.

const PERS := {
	"brawler": preload("res://ai/personalities/brawler.tres"),
	"caster": preload("res://ai/personalities/caster.tres"),
	"trickster": preload("res://ai/personalities/trickster.tres"),
}
const PROF := {
	"easy": preload("res://ai/profiles/easy.tres"),
	"normal": preload("res://ai/profiles/normal.tres"),
	"hard": preload("res://ai/profiles/hard.tres"),
}

var game: Node
var player: Wizard
var blue: Wizard
var green: Wizard
var purple: Wizard
var arena: Arena
var c: Vector2
var failures := 0


func _init() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.bot_ai = false
	game.shrink_arena = false
	game.rounds = false
	game.get_node("Arena").platform_radius_tiles = 38.0
	game.apply_settings = false
	game.title_screen = false
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(5)
	arena = game.get_node("Arena")
	player = game.get_node("Wizards/Player")
	blue = game.get_node("Wizards/BotBlue")
	green = game.get_node("Wizards/BotGreen")
	purple = game.get_node("Wizards/BotPurple")
	c = arena.get_center()
	player.get_node("PlayerController").process_mode = Node.PROCESS_MODE_DISABLED

	# Task 1: weighted choice + noise
	_test_weighted_choice()
	_test_reaction_jitter()
	_test_aim_noise()

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


# --- Task 1 ------------------------------------------------------------------

func _test_weighted_choice() -> void:
	print("weighted choice")
	var ai := _make_bot(blue, "caster", "normal")
	var n := {"a": 0, "b": 0, "c": 0}
	for i in 400:
		n[ai._choose({"a": 1.0, "b": 0.9, "c": 0.5})] += 1
	_check(n["a"] > 0 and n["b"] > 0, "picks both near-best actions (a %d, b %d)" % [n["a"], n["b"]])
	_check(n["a"] > n["b"], "the best one more often")
	_check(n["c"] == 0, "never one far below the best (%d)" % n["c"])
	var all_recover := true
	for i in 200:
		if ai._choose({"recover": 2.5, "dodge": 2.4}) != "recover":
			all_recover = false
	_check(all_recover, "recover is never randomized away")
	_check(ai._choose({}) == "", "nothing to do -> empty")
	_remove_bot(ai)


func _test_reaction_jitter() -> void:
	print("reaction jitter")
	var ai := _make_bot(blue, "caster", "normal")
	var lo := INF
	var hi := -INF
	var ok := true
	var base: float = PROF["normal"].reaction_delay
	for i in 200:
		var p := Projectile.new()
		var r: float = ai._roll(p)[2]
		lo = minf(lo, r)
		hi = maxf(hi, r)
		if r < base * 0.65 - 0.001 or r > base * 1.7 + 0.001:
			ok = false
		p.free()
	_check(ok, "reaction within [%.3f, %.3f] (got %.3f..%.3f)" % [base * 0.65, base * 1.7, lo, hi])
	_check(hi - lo > 0.1, "reaction really varies (spread %.3f)" % (hi - lo))
	_remove_bot(ai)


func _test_aim_noise() -> void:
	print("aim noise")
	_park_all()
	var ai := _make_bot(blue, "caster", "normal")
	_place(blue, c)
	_place(green, c + Vector2(300, 0))
	var err_max: float = PROF["normal"].aim_error_deg
	var inside := 0
	var wide := 0
	var ok := true
	for i in 300:
		var at := ai._aim_at(green, 0.0)
		var e := absf(rad_to_deg((at - blue.global_position).angle_to(green.global_position - blue.global_position)))
		if e > err_max * 2.0 + 0.01:
			ok = false
		if e <= err_max * 0.6:
			inside += 1
		if e > err_max:
			wide += 1
	_check(ok, "aim error within +/- 2x aim_error_deg")
	_check(inside > 150, "most shots near the middle (%d/300 within 0.6x)" % inside)
	# Bell curve, not a flat spread: now and then a shot goes properly wide.
	_check(wide >= 8 and wide <= 60, "a few shots wider than aim_error_deg (%d/300)" % wide)
	_remove_bot(ai)


# --- helpers -----------------------------------------------------------------

func _make_bot(w: Wizard, pers: String, prof: String) -> AIController:
	var ai := AIController.new()
	ai.personality = PERS[pers]
	ai.profile = PROF[prof]
	w.add_child(ai)
	return ai


func _remove_bot(ai: AIController) -> void:
	var w := ai.wizard
	ai.queue_free()
	w.move_target = null
	w.move_dir = Vector2.ZERO
	w.attack(null)


func _park_all() -> void:
	for p in get_nodes_in_group("projectiles"):
		p.queue_free()
	var spots := [Vector2(-900, -300), Vector2(-900, 300), Vector2(-600, -700), Vector2(-600, 700)]
	var all := [player, blue, green, purple]
	for i in all.size():
		_place(all[i], c + spots[i])
		for s in all[i].get_node("Spells").get_children():
			(s as Spell).cooldown_left = 0.0


func _place(w: Wizard, at: Vector2) -> void:
	w.reset(at)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
