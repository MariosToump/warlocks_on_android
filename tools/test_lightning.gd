extends SceneTree
## Lightning rework (v0.11): 450 px reach, a capsule hitbox like the drawn bolt,
## a wider tip zone with a knockback bonus, and bots that use the new reach.
##   godot --headless --path . -s tools/test_lightning.gd

var game: Node
var player: Wizard
var blue: Wizard
var green: Wizard
var purple: Wizard
var arena: Arena
var bolt: LightningSpell
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
	bolt = player.get_spell("E") as LightningSpell

	_test_reach()
	_test_tip_knockback()
	_test_tip_is_wider()
	_test_shield_still_blocks()
	await _test_bot_uses_reach()

	print("TEST PASSED (0 failures)" if failures == 0 else "TEST FAILED (%d failures)" % failures)
	quit(1 if failures else 0)


func _setup(target_at: Vector2) -> void:
	_park_all()
	_place(player, c)
	_place(blue, target_at)


func _zap(at: Vector2) -> void:
	bolt.release(at)


func _test_reach() -> void:
	print("reach")
	_check(is_equal_approx(bolt.max_range, 450.0), "max range 450 (%.0f)" % bolt.max_range)
	_setup(c + Vector2(420, 0))
	_zap(blue.global_position)
	_check(blue.health < 100.0, "hits at 420 px (hp %.1f)" % blue.health)
	_setup(c + Vector2(520, 0))
	_zap(blue.global_position)
	_check(is_equal_approx(blue.health, 100.0), "misses at 520 px")


func _test_tip_knockback() -> void:
	print("tip knockback")
	_setup(c + Vector2(200, 0))
	_zap(blue.global_position)
	var shaft := blue.knockback.length()
	_setup(c + Vector2(420, 0))
	_zap(blue.global_position)
	var tip := blue.knockback.length()
	_check(shaft > 0.0 and tip / shaft > 1.2 and tip / shaft < 1.3,
		"tip hit pushes ~1.25x harder (%.0f vs %.0f)" % [tip, shaft])


func _test_tip_is_wider() -> void:
	print("tip zone is wider")
	_setup(c + Vector2(420, 24))
	_zap(c + Vector2(420, 0))
	_check(blue.health < 100.0, "24 px off the line at the tip: hit")
	_setup(c + Vector2(200, 24))
	_zap(c + Vector2(200, 0))
	_check(is_equal_approx(blue.health, 100.0), "24 px off the line mid-bolt: miss")
	_setup(c + Vector2(200, 14))
	_zap(c + Vector2(200, 0))
	_check(blue.health < 100.0, "14 px off the line mid-bolt (inside the drawn bolt): hit")


func _test_shield_still_blocks() -> void:
	print("shield")
	_setup(c + Vector2(420, 0))
	blue.raise_shield(1.0)
	_zap(blue.global_position)
	_check(is_equal_approx(blue.health, 100.0) and blue.knockback == Vector2.ZERO, "shield blocks a tip hit")


func _test_bot_uses_reach() -> void:
	print("bots use the new reach")
	_park_all()
	# Random rocks can land between the two and (rightly) block the bolt.
	for rock in get_nodes_in_group("props"):
		rock.queue_free()
	await _frames(1)
	var ai := AIController.new()
	ai.personality = preload("res://ai/personalities/caster.tres")
	ai.profile = preload("res://ai/profiles/normal.tres")
	green.add_child(ai)
	_place(green, c)
	_place(blue, c + Vector2(400, 0))
	await _frames(2)
	ai.target = blue
	var far := ai._score_lightning()
	_check(far > 0.0, "caster scores lightning at 400 px (%.2f)" % far)
	_place(blue, c + Vector2(300, 0))
	var mid := ai._score_lightning()
	_check(far > mid, "a target in the tip zone scores higher (%.2f vs %.2f)" % [far, mid])
	ai.free()


# --- helpers -----------------------------------------------------------------

func _park_all() -> void:
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
