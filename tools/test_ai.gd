extends SceneTree
## AI bot tests (milestone 5).
##   godot --headless --path . -s tools/test_ai.gd
## The game starts with passive bots; each test gives one of them an
## AIController and places everyone else far away.

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

	await _test_fireball_in_range()
	await _test_reposition_approaches()
	await _test_never_walks_into_lava()
	await _test_recovers_from_knockback()
	await _test_hard_dodges()
	_test_reflected_projectile_is_danger()

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


# --- tests -------------------------------------------------------------------

func _test_fireball_in_range() -> void:
	print("fireball in range")
	_park_all()
	var ai := _make_bot(blue, "caster", "normal")
	_place(blue, c)
	_place(green, c + Vector2(300, 0))
	var fired := false
	var t := 0.0
	while t < 2.0 and not fired:
		await _frames(1)
		t += 1.0 / 60.0
		for p in get_nodes_in_group("projectiles"):
			if (p as Projectile).caster == blue:
				fired = true
	_check(fired or green.health < 100.0, "bot casts a fireball at an enemy in range within 2 s")
	_remove_bot(ai)


func _test_reposition_approaches() -> void:
	print("reposition")
	_park_all()
	var ai := _make_bot(blue, "brawler", "normal")
	_place(blue, c)
	_place(green, c + Vector2(400, 0))
	await _seconds(3.0)
	var d := blue.global_position.distance_to(green.global_position)
	_check(d < 120.0, "brawler closes from 400 px to < 120 px in 3 s (%.0f)" % d)
	_remove_bot(ai)


## First lava point east of the centre.
func _edge_east() -> Vector2:
	var p := c
	while not arena.is_lava_at(p):
		p.x += 4.0
	return p


func _test_never_walks_into_lava() -> void:
	print("lava safety")
	_park_all()
	var e := _edge_east()
	var ai := _make_bot(blue, "brawler", "normal")
	_place(blue, e - Vector2(40, 0))
	_place(green, e + Vector2(70, 0)) # standing in the lava, fireproof
	green.lava_dps = 0.0
	var touched := 0
	var t := 0.0
	while t < 10.0:
		await _frames(1)
		t += 1.0 / 60.0
		if arena.is_lava_at(blue.global_position):
			touched += 1
	_check(touched == 0 and blue.alive, "chasing a target in the lava, never steps on lava in 10 s (%d frames)" % touched)
	green.lava_dps = 8.0
	_remove_bot(ai)


func _test_recovers_from_knockback() -> void:
	print("knockback recovery")
	var e := _edge_east()
	var ok := 0
	for i in 5:
		_park_all()
		var ai := _make_bot(blue, "survivor", "normal")
		_place(blue, e - Vector2(120, 0))
		await _frames(2)
		blue.apply_knockback(Vector2(450, 0))
		await _seconds(3.0)
		if blue.alive and not arena.is_lava_at(blue.global_position):
			ok += 1
		_remove_bot(ai)
		await _frames(1)
	_check(ok >= 3, "knocked toward lava: back on stone after 3 s in %d/5 (need 3)" % ok)


func _test_hard_dodges() -> void:
	print("hard dodges")
	var still := AIProfile.new() # never dodges or shields: the baseline
	still.dodge_chance = 0.0
	still.shield_reflect_chance = 0.0
	var base := await _fireballs_avoided(still)
	var hard := await _fireballs_avoided(PROF["hard"])
	_check(base <= 2, "baseline: a bot that doesn't dodge avoids few (%d/8)" % base)
	_check(hard >= 5, "hard bot dodges or shields fireballs: %d/8 avoided (need 5)" % hard)


## Green shoots 8 fireballs at a survivor bot from 8 directions; returns how
## many didn't hurt it.
func _fireballs_avoided(prof: AIProfile) -> int:
	_park_all()
	var ai := _make_bot(blue, "survivor", "hard")
	ai.profile = prof
	var avoided := 0
	for i in 8:
		blue.reset(c)
		green.reset(c + Vector2.from_angle(i * TAU / 8.0) * 400.0)
		(green.get_spell("Q") as Spell).cooldown_left = 0.0
		(blue.get_spell("R") as Spell).cooldown_left = 0.0
		(blue.get_spell("W") as Spell).cooldown_left = 0.0
		await _frames(2)
		var cast := green.cast("Q", blue.global_position)
		await _seconds(1.2)
		if cast and blue.alive and blue.health >= 99.99:
			avoided += 1
	_remove_bot(ai)
	return avoided


func _test_reflected_projectile_is_danger() -> void:
	print("reflected projectiles")
	_park_all()
	var ai := _make_bot(blue, "caster", "normal")
	var p: Projectile = load("res://scenes/projectile_fireball.tscn").instantiate()
	p.caster = blue
	p.age = 1.0
	p.speed = 0.0
	game.get_node("Wizards").add_child(p)
	p.global_position = blue.global_position + Vector2(200, 0)
	_check(not ai._visible_projectiles().has(p), "own projectile is not a threat")
	p.caster = green # as if reflected by green's shield
	_check(ai._visible_projectiles().has(p), "projectile reflected by an enemy is a threat")
	p.age = 0.0
	_check(not ai._visible_projectiles().has(p), "a brand-new projectile is not seen yet (reaction delay)")
	p.queue_free()
	_remove_bot(ai)


# --- helpers -----------------------------------------------------------------

## "survivor" = a bot that only dodges, shields and recovers, and otherwise
## stands still (so survival tests can't pass by accident).
func _make_bot(w: Wizard, pers: String, prof: String) -> AIController:
	var ai := AIController.new()
	if pers == "survivor":
		var sp := AIPersonality.new()
		sp.weights = {"dodge": 1.0, "recover": 1.0, "shield": 1.0, "fireball": 0.0,
			"lightning": 0.0, "staff": 0.0, "blink_in": 0.0, "reposition": 0.0}
		ai.personality = sp
	else:
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


## Everyone to far corners of the platform, full health, nothing flying.
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


func _seconds(s: float) -> void:
	await create_timer(s).timeout
