extends SceneTree
## Homing Orb tests: curves onto a moving enemy, never chases its caster,
## a reflected orb hunts the new owner's enemies, expires at max range.
##   godot --headless --path . -s tools/test_homing.gd

var game: Node
var player: Wizard
var blue: Wizard
var green: Wizard
var purple: Wizard
var c: Vector2
var failures := 0


func _init() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.bot_ai = false
	game.shrink_arena = false
	game.rounds = false
	game.apply_settings = false
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(3)
	player = game.player
	blue = game.get_node("Wizards/BotBlue")
	green = game.get_node("Wizards/BotGreen")
	purple = game.get_node("Wizards/BotPurple")
	c = game.arena.get_center()
	game.get_node("Wizards/Player/PlayerController").process_mode = Node.PROCESS_MODE_DISABLED
	game.gold[player] = 100
	Shop.buy_spell(game, player, "homing")
	var orb_spell := player.get_spell("D") as HomingOrbSpell

	print("curves onto a moving target")
	_place(player, c)
	_place(blue, c + Vector2(330, -40))
	_place(green, c + Vector2(-900, 0))
	_place(purple, c + Vector2(0, 900))
	blue.move_dir = Vector2(0, 1) # walks down across the orb's path
	var hp := blue.health
	_check(player.cast("D", c + Vector2(400, -200)), "cast the orb (aimed well off target)")
	var t := 0.0
	while t < 3.0 and is_equal_approx(blue.health, hp):
		await _frames(1)
		t += 1.0 / 60.0
	blue.move_dir = Vector2.ZERO
	_check(blue.health < hp, "it curved round and hit (%.1f s)" % t)
	_check(is_equal_approx(hp - blue.health, orb_spell.damage_by_level[0]), "damage %d" % int(hp - blue.health))

	print("never chases its caster")
	await _seconds(orb_spell.cooldown() + 0.1)
	_place(blue, c + Vector2(1500, 0))
	_place(player, c)
	player.cast("D", c + Vector2(0, -300))
	await _seconds(0.35)
	var orb := _find_orb()
	_check(orb != null and orb.homing_target() == null, "with only its caster near, no target")
	var y0 := orb.global_position.y if orb else 0.0
	await _seconds(0.3)
	_check(orb != null and is_instance_valid(orb) and orb.global_position.y < y0 - 60.0 and absf(orb.global_position.x - c.x) < 4.0,
			"flies straight on, away from its caster")

	print("reflected orb hunts the new owner's enemies")
	await _seconds(orb_spell.cooldown())
	_place(player, c)
	_place(green, c + Vector2(260, 0))
	green.raise_shield(3.0)
	var php := player.health
	player.cast("D", green.global_position)
	t = 0.0
	var flipped := false
	while t < 4.0 and is_equal_approx(player.health, php):
		await _frames(1)
		t += 1.0 / 60.0
		var o := _find_orb()
		if o and o.caster == green:
			flipped = true
	_check(flipped, "shield turns the orb over to green")
	_check(player.health < php, "and it comes back for the caster (%.1f s)" % t)

	print("expires at max range")
	await _seconds(orb_spell.cooldown())
	_place(player, c)
	_place(green, c + Vector2(-1500, 0))
	player.cast("D", c + Vector2(0, -100))
	await _seconds(0.3)
	orb = _find_orb()
	_check(orb != null, "orb in flight")
	await _seconds(orb_spell.max_range / orb_spell.speed + 0.3)
	_check(not is_instance_valid(orb) or orb.is_queued_for_deletion(), "gone after %d px" % int(orb_spell.max_range))

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _place(w: Wizard, at: Vector2) -> void:
	w.global_position = at
	w.knockback = Vector2.ZERO
	w.reset_physics_interpolation()


func _find_orb() -> Projectile:
	for n in game.wizards.get_children():
		if n is Projectile and n.homing_turn > 0.0 and not n.is_queued_for_deletion():
			return n
	return null


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(s: float) -> void:
	await create_timer(s).timeout
