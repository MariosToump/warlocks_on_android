extends SceneTree
## Edge cases for the shop spells (spell audit 2026-11-27, warlocks-spell-author
## step 7): the caster dies mid-cast, a stone in the way, lava, a shield, the
## caster dying while the spell is still out. Dark Mirror and Time Stop have
## their own files (tools/test_dark_mirror.gd, tools/test_time_stop.gd).
##   godot --headless --path . -s tools/test_spell_edges.gd

var game: Node
var player: Wizard
var blue: Wizard
var green: Wizard
var purple: Wizard
var arena: Arena
var c: Vector2
var failures := 0

const GROUPS := ["projectiles", "boomerangs", "meteors", "wells", "time_stops", "mirrors"]


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
	game.state = game.State.FREE

	print("caster dies mid-cast: nothing comes out")
	for id in ["homing", "boomerang", "swap", "meteor", "well", "timestop", "mirror"]:
		_park_all()
		_place(player, c)
		_place(blue, c + Vector2(220, 0))
		var slot := _give(player, id)
		await _frames(2)
		var before := _count_all()
		var props_before := get_nodes_in_group("props").size()
		_check(player.cast(slot, blue.global_position), "%s: cast starts" % id)
		player.take_damage(1000.0) # dies before release_time
		await _seconds(0.6)
		_check(_count_all() == before and get_nodes_in_group("props").size() == props_before,
				"%s: a dead caster releases nothing" % id)
		Shop.sell_spell(game, player, id)
	_place(player, c)

	await _homing()
	await _boomerang()
	await _swap()
	await _meteor()
	await _well()
	await _time_stop()

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _homing() -> void:
	print("homing orb")
	_park_all()
	var slot := _give(player, "homing")
	_place(player, c)
	_place(blue, c + Vector2(300, 0))
	var rock := Prop.make(Prop.Kind.PILLAR, c + Vector2(150, 0), arena)
	game.get_node("Wizards").add_child(rock)
	await _frames(2)
	_cast_now(player, slot, blue.global_position)
	await _seconds(1.5)
	_check(blue.health == blue.max_health, "a stone in the way stops it (blue hp %.0f)" % blue.health)
	_check(_count("projectiles") == 0, "the orb is gone after hitting the stone")
	rock.queue_free()
	# Over lava: it keeps flying (projectiles cross lava) and still homes.
	_park_all()
	var edge := _lava_point(Vector2.LEFT)
	_place(player, edge + Vector2(140, 0))
	_place(blue, edge + Vector2(-60, 120)) # out on the lava, off the straight line
	blue.knockback = Vector2.ZERO
	await _frames(2)
	_cast_now(player, slot, edge + Vector2(-60, 0))
	var t := 0
	while blue.health == blue.max_health and t < 180:
		await _frames(1)
		t += 1
	_check(blue.health < blue.max_health, "flies over lava and still curves onto a target")
	# The caster dies while it's flying: it carries on (no owner needed).
	_park_all()
	_place(player, c)
	_place(blue, c + Vector2(350, 0))
	await _frames(2)
	_cast_now(player, slot, blue.global_position)
	await _frames(5)
	player.take_damage(1000.0)
	t = 0
	while blue.health == blue.max_health and t < 180:
		await _frames(1)
		t += 1
	_check(blue.health < blue.max_health, "still hits after its caster died")
	_check(blue.last_attacker == player, "the kill credit still goes to the caster")
	_place(player, c)
	Shop.sell_spell(game, player, "homing")


func _boomerang() -> void:
	print("boomerang")
	_park_all()
	var slot := _give(player, "boomerang")
	_place(player, c)
	_place(blue, c + Vector2(300, 0))
	var rock := Prop.make(Prop.Kind.PILLAR, c + Vector2(140, 0), arena)
	game.get_node("Wizards").add_child(rock)
	await _frames(2)
	_cast_now(player, slot, blue.global_position)
	await _seconds(1.0)
	_check(_count("boomerangs") == 0, "a stone ends the blade")
	_check(blue.health == blue.max_health, "nothing behind the stone is hit")
	rock.queue_free()
	# The caster dies while the blade is out: it doesn't fly forever.
	_park_all()
	_place(player, c)
	await _frames(2)
	_cast_now(player, slot, c + Vector2(400, 0))
	await _frames(10)
	player.take_damage(1000.0)
	await _seconds(3.0)
	_check(_count("boomerangs") == 0, "the blade goes when its caster is dead")
	_place(player, c)
	Shop.sell_spell(game, player, "boomerang")


func _swap() -> void:
	print("swap")
	_park_all()
	var slot := _give(player, "swap")
	_place(player, c)
	_place(blue, c + Vector2(300, 0))
	var rock := Prop.make(Prop.Kind.PILLAR, c + Vector2(150, 0), arena)
	game.get_node("Wizards").add_child(rock)
	await _frames(2)
	_cast_now(player, slot, blue.global_position)
	await _seconds(0.8)
	_check(player.global_position.distance_to(c) < 5.0, "a stone in the way: no swap")
	rock.queue_free()
	# Owner dead when it lands: no swap.
	_park_all()
	_place(player, c)
	_place(blue, c + Vector2(400, 0))
	await _frames(2)
	_cast_now(player, slot, blue.global_position)
	await _frames(3)
	player.take_damage(1000.0)
	await _seconds(0.8)
	_check(blue.global_position.distance_to(c + Vector2(400, 0)) < 5.0, "a dead owner can't swap anyone")
	# Shielded target: reflected, no swap with the shielder.
	_place(player, c)
	_place(blue, c + Vector2(300, 0))
	await _frames(2)
	blue.cast("R", blue.global_position)
	await _frames(3)
	_cast_now(player, slot, blue.global_position)
	await _seconds(0.5)
	_check(blue.global_position.distance_to(c + Vector2(300, 0)) < 5.0, "a shield stops the swap")
	_place(player, c)
	Shop.sell_spell(game, player, "swap")


func _meteor() -> void:
	print("meteor")
	_park_all()
	var slot := _give(player, "meteor")
	# On lava: a blast but no crater.
	var lava := _lava_point(Vector2.UP) + Vector2(0, -80)
	_place(player, lava + Vector2(0, 300))
	await _frames(2)
	var craters := get_nodes_in_group("craters").size()
	_cast_now(player, slot, lava)
	await _seconds(1.2)
	_check(get_nodes_in_group("craters").size() == craters, "no crater on lava")
	# The caster dies before it lands: it still lands, and the push still counts.
	_park_all()
	_place(player, c)
	_place(blue, c + Vector2(300, 0))
	await _frames(2)
	_cast_now(player, slot, blue.global_position)
	await _frames(3)
	player.take_damage(1000.0)
	await _seconds(1.2)
	_check(blue.health < blue.max_health, "lands after its caster died")
	_check(blue.last_attacker == player, "the kill credit still goes to the caster")
	# A shield takes the blast.
	_park_all()
	_place(player, c)
	_place(green, c + Vector2(300, 0))
	await _frames(2)
	_cast_now(player, slot, green.global_position)
	await _seconds(0.5)
	green.cast("R", green.global_position)
	await _seconds(0.7)
	_check(green.health == green.max_health, "a shield takes the blast")
	# Boulders in the blast get shoved.
	_park_all()
	_place(player, c)
	var boulder := Prop.make(Prop.Kind.BOULDER, c + Vector2(330, 0), arena)
	game.get_node("Wizards").add_child(boulder)
	await _frames(2)
	_cast_now(player, slot, c + Vector2(300, 0))
	await _seconds(1.3)
	_check(boulder.global_position.distance_to(c + Vector2(330, 0)) > 20.0, "a boulder in the blast is shoved")
	boulder.queue_free()
	_place(player, c)
	Shop.sell_spell(game, player, "meteor")


func _well() -> void:
	print("gravity well")
	_park_all()
	var slot := _give(player, "well")
	_place(player, c)
	_place(blue, c + Vector2(400, 0))
	await _frames(2)
	_cast_now(player, slot, blue.global_position + Vector2(100, 0))
	await _frames(5)
	player.take_damage(1000.0)
	await _seconds(3.5)
	_check(_count("wells") == 0, "ends on time after its caster died")
	# Placed on lava next to the rim: drags a wizard off the stone.
	_park_all()
	var edge := _lava_point(Vector2.RIGHT)
	_place(player, edge + Vector2(-400, 0))
	_place(blue, edge + Vector2(-70, 0))
	await _frames(2)
	_cast_now(player, slot, edge + Vector2(40, 0))
	await _seconds(2.0)
	_check(blue.on_lava or not blue.alive, "a well on the lava drags a wizard off the rim")
	_place(player, c)
	_place(blue, c + Vector2(300, 0))
	Shop.sell_spell(game, player, "well")


func _time_stop() -> void:
	print("time stop")
	_park_all()
	var slot := _give(player, "timestop")
	_place(player, c)
	_place(blue, c + Vector2(300, 0))
	await _frames(2)
	_cast_now(player, slot, blue.global_position)
	await _frames(3)
	player.take_damage(1000.0) # the caster dies: the field still runs its time
	await _seconds(0.3)
	_check(blue.frozen, "blue stays frozen after the caster died")
	await _seconds(1.5)
	_check(_count("time_stops") == 0 and not blue.frozen, "the field ends on time")
	# On lava: a frozen wizard still burns.
	_park_all()
	var edge := _lava_point(Vector2.RIGHT) + Vector2(30, 0)
	_place(player, edge + Vector2(-350, 0))
	_place(blue, edge)
	await _frames(2)
	_cast_now(player, slot, edge)
	await _seconds(1.0)
	_check(blue.health < blue.max_health, "frozen on the lava, it burns (hp %.0f)" % blue.health)
	# A shield doesn't stop the freeze (it's not a spell that flies).
	_park_all()
	_place(player, c)
	_place(blue, c + Vector2(300, 0))
	await _frames(2)
	blue.cast("R", blue.global_position)
	await _frames(3)
	_cast_now(player, slot, blue.global_position)
	await _frames(3)
	_check(blue.frozen, "a shielded wizard is frozen too")
	await _seconds(2.0)
	_place(player, c)
	Shop.sell_spell(game, player, "timestop")


# --- helpers ---------------------------------------------------------------------

func _count(group: String) -> int:
	var n := 0
	for x in get_nodes_in_group(group):
		if not x.is_queued_for_deletion():
			n += 1
	return n


func _count_all() -> int:
	var n := 0
	for g in GROUPS:
		n += _count(g)
	return n


## The first lava point going out from the centre in `dir`.
func _lava_point(dir: Vector2) -> Vector2:
	var p := c
	while not arena.is_lava_at(p):
		p += dir * 8.0
	return p


func _find_projectile() -> Projectile:
	for n in get_nodes_in_group("projectiles"):
		if n is Projectile and not n.is_queued_for_deletion():
			return n
	return null


func _give(w: Wizard, id: String) -> String:
	game.gold[w] = 100
	Shop.buy_spell(game, w, id)
	return w.slot_of(id)


func _cast_now(w: Wizard, slot: String, at: Vector2) -> void:
	var s := w.get_spell(slot)
	s.cooldown_left = 0.0
	s.release(at)


func _park_all() -> void:
	for g in GROUPS + ["props"]:
		for p in get_nodes_in_group(g):
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
	await _frames(roundi(s * 60.0))
