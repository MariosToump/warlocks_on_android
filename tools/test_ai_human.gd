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
	# Task 2: mood + opening watch
	_test_mood_roll()
	await _test_watch_blocks_attacks()
	await _test_watch_ends()
	await _test_recover_never_random()
	# Task 3: memory + opportunity + risk
	await _test_memory_shield_window()
	_test_memory_no_cheat()
	await _test_memory_freed_enemy()
	await _test_opportunity()
	await _test_risk_prefers_exposed_target()

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


# --- Task 2 ------------------------------------------------------------------

func _test_mood_roll() -> void:
	print("mood roll")
	var odds := {"aggressive": 0.2, "cautious": 0.2, "opportunist": 0.6}
	var n := {"aggressive": 0, "cautious": 0, "opportunist": 0}
	for i in 600:
		n[AIMood.roll(odds).name] += 1
	var share: float = n["opportunist"] / 600.0
	_check(absf(share - 0.6) <= 0.08, "opportunist share follows the odds (%.2f)" % share)
	_check(n["aggressive"] > 0 and n["cautious"] > 0, "every mood shows up %s" % n)
	_check(AIMood.roll({}).name in n, "empty odds fall back to an even roll")
	var cautious := AIMood.make("cautious")
	_check(cautious.watch_min >= 2.0 and cautious.watch_max <= 4.0 and cautious.attack_mult < 1.0,
		"cautious: watches 2-4 s, attacks less")
	var neutral := _make_bot(blue, "caster", "normal")
	_check(neutral.mood.name == "neutral" and not neutral.watching(), "a never-reset bot is neutral, no watch")
	_remove_bot(neutral)


## Caster in a cautious watch against an enemy in fireball range.
func _watching_caster() -> AIController:
	_park_all()
	var ai := _make_bot(blue, "caster", "normal")
	_place(blue, c)
	_place(green, c + Vector2(300, 0))
	ai._start_mood(AIMood.make("cautious"))
	ai._watch_until = ai._now + 2.0
	return ai


func _blue_cast_something() -> bool:
	for p in get_nodes_in_group("projectiles"):
		if (p as Projectile).caster == blue:
			return true
	return blue.is_casting()


func _test_watch_blocks_attacks() -> void:
	print("watch blocks attacks")
	var ai := _watching_caster()
	var cast := false
	for i in 90:
		await _frames(1)
		cast = cast or _blue_cast_something()
	_check(not cast, "no attack while watching (1.5 s, enemy at 300 px)")
	_check(ai.preferred_distance() >= 260.0, "keeps >= 260 px while watching (%.0f)" % ai.preferred_distance())
	_remove_bot(ai)


func _test_watch_ends() -> void:
	print("watch ends")
	var ai := _watching_caster()
	await _frames(10)
	_check(ai.watching(), "watching at first")
	blue.take_damage(3.0, green)
	await _frames(30)
	_check(not ai.watching(), "being hit ends the watch")
	_remove_bot(ai)
	ai = _watching_caster()
	ai._start_mood(AIMood.make("opportunist")) # rolls a 3-5 s watch
	await _frames(int(5.1 * 60))
	_check(not ai.watching(), "the watch never lasts past 5 s")
	_remove_bot(ai)


func _test_recover_never_random() -> void:
	print("recover never random")
	_park_all()
	var prof := (PROF["normal"] as AIProfile).duplicate() as AIProfile
	prof.hesitate_chance = 1.0
	prof.choice_spread = 1.0
	var ai := AIController.new()
	ai.personality = PERS["caster"]
	ai.profile = prof
	blue.add_child(ai)
	ai._start_mood(AIMood.make("cautious"))
	var p := c
	while not arena.is_lava_at(p):
		p.x += 4.0
	_place(blue, p + Vector2(40, 0))
	await _frames(1)
	var ok := true
	var thinks := 0
	for i in 60:
		await _frames(1)
		if blue.on_lava and ai.current_action != "":
			thinks += 1
			ok = ok and ai.current_action == "recover"
	_check(ok and thinks > 0, "on lava, always recover (even hesitant + watching) (%d frames)" % thinks)
	_remove_bot(ai)


# --- Task 3 ------------------------------------------------------------------

## `w` casts `slot` for real (the bot sees it through cast_started).
func _cast_and_wait(w: Wizard, slot: String, at: Vector2) -> void:
	w.get_spell(slot).cooldown_left = 0.0
	w.cast(slot, at)
	await _frames(20)


func _test_memory_shield_window() -> void:
	print("memory: shield window")
	_park_all()
	var ai := _make_bot(blue, "caster", "normal")
	await _frames(2)
	_check(not ai.shield_probably_down(purple), "nothing seen yet -> not down")
	await _cast_and_wait(purple, "R", purple.global_position)
	_check(ai.shield_probably_down(purple), "saw the shield go up -> probably down for a while")
	var est: float = blue.get_spell("R").cooldown_by_level[0] * 0.9
	ai._now += est + 0.1
	_check(not ai.shield_probably_down(purple), "after the estimate (%.1f s) it counts as back" % est)
	await _cast_and_wait(purple, "R", purple.global_position)
	_check(ai.shield_probably_down(purple), "a second shield refreshes the window")
	await _cast_and_wait(purple, "W", purple.global_position + Vector2(50, 0))
	_check(ai.blink_probably_down(purple), "blink seen -> probably down")
	_remove_bot(ai)


func _test_memory_no_cheat() -> void:
	print("memory: no cheating")
	_park_all()
	var ai := _make_bot(blue, "caster", "normal")
	ai.memory.watch(green)
	green.get_spell("R").cooldown_left = 5.0 # on cooldown, but nobody saw a cast
	_check(not ai.shield_probably_down(green), "an unseen cooldown is not known")
	green.get_spell("R").cooldown_left = 0.0
	_remove_bot(ai)


func _test_memory_freed_enemy() -> void:
	print("memory: freed enemy")
	_park_all()
	var ai := _make_bot(blue, "caster", "normal")
	var extra: Wizard = load("res://scenes/wizard.tscn").instantiate()
	game.get_node("Wizards").add_child(extra)
	extra.reset(c + Vector2(-700, 0))
	await _frames(2)
	ai.memory.watch(extra)
	await _cast_and_wait(extra, "R", extra.global_position)
	_check(ai.memory.known() >= 1, "remembers the extra wizard's cast")
	extra.free()
	await _frames(2)
	ai.memory.prune()
	_check(ai.memory.known() == 0, "a freed wizard is forgotten (%d left)" % ai.memory.known())
	_remove_bot(ai)


## The spot `inside` px inside the east shore.
func _near_east_lava(inside: float) -> Vector2:
	var p := c
	while not arena.is_lava_at(p):
		p.x += 4.0
	return p - Vector2(inside, 0)


func _test_opportunity() -> void:
	print("opportunity")
	_park_all()
	var ai := _make_bot(blue, "caster", "normal")
	_place(purple, c)
	await _frames(2)
	var calm := ai.opportunity(purple)
	_check(calm < 0.1, "healthy enemy in the middle: low (%.2f)" % calm)
	_place(purple, _near_east_lava(30.0))
	purple.health = 20.0
	await _cast_and_wait(purple, "R", purple.global_position)
	var open := ai.opportunity(purple)
	_check(open >= 0.8, "hurt, by the lava, shield used: high (%.2f)" % open)
	_check(open <= 1.0, "capped at 1")
	_remove_bot(ai)


func _test_risk_prefers_exposed_target() -> void:
	print("risk: exposed target")
	_park_all()
	var ai := _make_bot(blue, "caster", "normal")
	_place(blue, c)
	_place(green, c + Vector2(0, 240))
	_place(purple, c + Vector2(0, -250))
	await _frames(2)
	_check(ai._pick_target() == green, "both fine: the nearer one")
	await _cast_and_wait(purple, "R", purple.global_position)
	await _cast_and_wait(purple, "W", purple.global_position + Vector2(40, 0))
	_place(purple, c + Vector2(0, -250))
	purple.take_damage(1.0, player) # busy fighting someone else
	ai.target = null
	var opp := ai.opportunity(purple)
	_check(opp >= 0.6, "purple is exposed (%.2f)" % opp)
	_check(ai._pick_target() == purple, "goes for the exposed one")
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
	ai.free() # now, not at frame end: a queued bot would still think (and cast) once
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
