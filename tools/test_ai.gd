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
