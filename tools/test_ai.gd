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
	game.shrink_arena = false
	game.rounds = false
	game.get_node("Arena").platform_radius_tiles = 38.0 # these tests place wizards ~900 px out
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

	await _test_fireball_in_range()
	await _test_reposition_approaches()
	await _test_never_walks_into_lava()
	await _test_recovers_from_knockback()
	await _test_hard_dodges()
	_test_reflected_projectile_is_danger()
	await _test_lightning_at_short_range()
	await _test_brawler_uses_staff()
	await _test_personalities_keep_different_distances()
	await _test_dead_target()
	await _test_reflect_resets_age()
	await _test_no_freeze_at_shore()
	await _test_knockback_noticed_between_thinks()
	_test_shield_respects_cast_pause()
	_test_mid_cast_shield_rolled_once()
	_test_blink_in_within_blink_range()
	await _test_idle_wanders_to_centre()
	await _test_freed_target()
	_test_rolls_pruned_not_wiped()
	await _test_leaves_doomed_ring()
	await _test_retaliates_against_attacker()

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
	(blue.get_spell("E") as Spell).cooldown_left = 99.0 # walking, not zapping it away
	await _open_up(green, c + Vector2(400, 0))
	var d := INF
	var t := 0.0
	while t < 3.0:
		await _frames(1)
		t += 1.0 / 60.0
		d = minf(d, blue.global_position.distance_to(green.global_position))
	_check(d < 150.0, "brawler closes on an open target from 400 px to < 150 px in 3 s (closest %.0f)" % d)
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
	green.lava_dps = 20.0
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


## Time until `slot` of `w` goes on cooldown (or -1 if not within `limit` s).
func _time_to_use(w: Wizard, slot: String, limit: float) -> float:
	var t := 0.0
	while t < limit:
		await _frames(1)
		t += 1.0 / 60.0
		if not w.get_spell(slot).is_ready():
			return t
	return -1.0


func _test_lightning_at_short_range() -> void:
	print("lightning")
	_park_all()
	var ai := _make_bot(blue, "caster", "normal")
	_place(blue, c)
	_place(green, c + Vector2(150, 0))
	var t := await _time_to_use(blue, "E", 4.0)
	_check(t >= 0.0, "caster uses lightning on an enemy 150 px away within 4 s (%.1f s)" % t)
	_remove_bot(ai)


func _test_brawler_uses_staff() -> void:
	print("staff")
	_park_all()
	var ai := _make_bot(blue, "brawler", "normal")
	_place(blue, c)
	(blue.get_spell("E") as Spell).cooldown_left = 99.0 # the staff, not a zap
	await _open_up(green, c + Vector2(200, 0))
	var t := await _time_to_use(blue, "A", 4.0)
	_check(t >= 0.0, "brawler walks up to an open target and swings within 4 s (%.1f s)" % t)
	_remove_bot(ai)


## Mean distance to a passive target over 6 s.
func _mean_distance(pers: String) -> float:
	_park_all()
	var ai := _make_bot(blue, pers, "normal")
	_place(blue, c)
	_place(green, c + Vector2(250, 0))
	green.lava_dps = 0.0
	var sum := 0.0
	var n := 0
	var t := 0.0
	while t < 6.0:
		await _frames(1)
		t += 1.0 / 60.0
		green.health = 100.0 # keep it alive and in place-ish
		sum += blue.global_position.distance_to(green.global_position)
		n += 1
	green.lava_dps = 20.0
	_remove_bot(ai)
	return sum / n


func _test_personalities_keep_different_distances() -> void:
	print("personalities")
	var brawler := await _mean_distance("brawler")
	var caster := await _mean_distance("caster")
	_check(brawler + 50.0 < caster, "brawler fights closer than caster (%.0f vs %.0f px)" % [brawler, caster])


func _test_dead_target() -> void:
	print("dead target")
	_park_all()
	var ai := _make_bot(blue, "trickster", "normal")
	_place(blue, c)
	_place(green, c + Vector2(150, 0))
	await _seconds(0.5)
	# Kill every possible target.
	for w in [green, player, purple]:
		w.take_damage(1000.0)
	await _seconds(1.5)
	_check(ai.target == null or ai.target.alive, "no dead target kept (%s)" % ai.target)
	_check(blue.alive, "bot fine with nobody to fight")
	await _seconds(1.5) # everyone respawns
	_remove_bot(ai)


func _test_reflect_resets_age() -> void:
	print("reflection resets age")
	_park_all()
	_place(green, c)
	green.raise_shield(1.0)
	var p: Projectile = load("res://scenes/projectile_fireball.tscn").instantiate()
	p.caster = blue
	p.direction = Vector2.LEFT
	p.age = 1.0
	game.get_node("Wizards").add_child(p)
	p.global_position = c + Vector2(30, 0)
	await _frames(6)
	_check(is_instance_valid(p) and p.caster == green, "fireball reflected by green's shield")
	_check(is_instance_valid(p) and p.age < 0.2, "reflection restarts the projectile's age (%.2f)" % (p.age if is_instance_valid(p) else -1.0))
	if is_instance_valid(p):
		p.queue_free()
	green.shield_left = 0.0


## Target stands in the lava right by the shore: the brawler must not stall
## on a staff swing it can never make.
func _test_no_freeze_at_shore() -> void:
	print("no freeze at shore")
	_park_all()
	var e := _edge_east()
	var ai := _make_bot(blue, "brawler", "normal")
	_place(blue, e - Vector2(30, 0))
	_place(green, e + Vector2(40, 0))
	green.lava_dps = 0.0
	green.knockback_friction = 10000.0 # can't be blasted away
	var staff_thinks := 0
	var thinks := 0
	var t := 0.0
	while t < 4.0:
		await _frames(1)
		t += 1.0 / 60.0
		if ai.current_action != "":
			thinks += 1
			if ai.current_action == "staff":
				staff_thinks += 1
	_check(staff_thinks == 0, "never picks the staff against a target in the lava (%d/%d frames)" % [staff_thinks, thinks])
	_check(ai._safe_step(green.global_position) != null, "safe step from the shore always offers a way to go")
	green.lava_dps = 20.0
	green.knockback_friction = 3.0
	_remove_bot(ai)


## A slow-thinking bot still reacts to being knocked toward lava within about
## half its reaction delay, not whenever its next think comes.
func _test_knockback_noticed_between_thinks() -> void:
	print("knockback noticed between thinks")
	_park_all()
	var e := _edge_east()
	var prof: AIProfile = PROF["easy"].duplicate()
	prof.think_interval = 5.0
	var ai := _make_bot(blue, "survivor", "easy")
	ai.profile = prof
	_place(blue, e - Vector2(120, 0))
	await _frames(2)
	ai._think_left = 5.0
	blue.apply_knockback(Vector2(450, 0))
	await _seconds(prof.reaction_delay * 0.5 + 0.12)
	_check(ai.current_action == "recover", "recovering %.2f s after the hit despite a 5 s think interval (%s)"
		% [prof.reaction_delay * 0.5 + 0.12, ai.current_action])
	_remove_bot(ai)


func _fake_projectile_at(target: Wizard, caster: Wizard) -> Projectile:
	var p: Projectile = load("res://scenes/projectile_fireball.tscn").instantiate()
	p.caster = caster
	p.direction = Vector2.LEFT
	p.age = 5.0
	p.process_mode = Node.PROCESS_MODE_DISABLED
	game.get_node("Wizards").add_child(p)
	p.global_position = target.global_position + Vector2(100, 0)
	return p


func _test_shield_respects_cast_pause() -> void:
	print("shield respects cast pause")
	_park_all()
	var ai := _make_bot(blue, "brawler", "easy")
	var p := _fake_projectile_at(blue, green)
	ai._danger = p
	ai._rolls[p.get_instance_id()] = [false, true]
	ai._last_cast = ai._now
	_check(ai._score_shield() == 0.0, "no shield right after another cast (pause %.1f s)" % ai.profile.cast_pause)
	ai._last_cast = -100.0
	_check(ai._score_shield() > 0.0, "shield once the pause is over")
	p.free()
	ai._danger = null
	_remove_bot(ai)


func _test_mid_cast_shield_rolled_once() -> void:
	print("mid-cast shield rolled once per cast")
	_park_all()
	var prof: AIProfile = PROF["normal"].duplicate()
	prof.shield_reflect_chance = 0.5
	var ai := _make_bot(blue, "brawler", "normal")
	ai.profile = prof
	_place(blue, c)
	_place(green, c + Vector2(40, 0))
	ai.target = green
	green._casting = green.get_spell("Q")
	var seen := {}
	for i in 40:
		seen[ai._score_shield()] = true
	green._casting = null
	_check(seen.size() == 1, "same answer for the whole cast (%s)" % [seen.keys()])
	_remove_bot(ai)


func _test_blink_in_within_blink_range() -> void:
	print("blink-in only within blink range")
	_park_all()
	var e := _edge_east()
	var ai := _make_bot(blue, "trickster", "normal")
	var blink := blue.get_spell("W") as BlinkSpell
	_place(green, e - Vector2(40, 0))
	_place(blue, green.global_position - Vector2(150, 0))
	ai.target = green
	var near := ai._score_blink_in()
	blink.max_distance = 100.0 # the landing spot is ~124 px away
	var far := ai._score_blink_in()
	blink.max_distance = 200.0
	_check(near > 0.0 and far == 0.0, "blink-in needs the landing spot in blink range (%.1f / %.1f)" % [near, far])
	_remove_bot(ai)


func _test_idle_wanders_to_centre() -> void:
	print("idle without enemies")
	_park_all()
	var ai := _make_bot(blue, "brawler", "normal")
	_place(blue, c + Vector2(500, 0))
	game.respawn_delay = 10.0
	for w in [green, player, purple]:
		w.take_damage(1000.0)
	await _seconds(1.8)
	var d := blue.global_position.distance_to(c)
	_check(d < 400.0, "with nobody to fight, heads toward the middle (%.0f px from it)" % d)
	game.respawn_delay = 2.0
	for w in [green, player, purple]:
		w.reset(c + Vector2(-900, 0))
	_remove_bot(ai)


func _test_freed_target() -> void:
	print("freed target")
	_park_all()
	var ai := _make_bot(blue, "brawler", "normal")
	_place(blue, c)
	game.respawn_delay = 10.0
	for w in [green, player, purple]:
		w.take_damage(1000.0)
	var temp: Wizard = game.WIZARD.instantiate()
	temp.arena = arena
	game.get_node("Wizards").add_child(temp)
	temp.global_position = c + Vector2(60, 0)
	await _seconds(0.6)
	var had := ai.target == temp
	temp.queue_free()
	await _seconds(0.6)
	_check(had and ai.target == null, "drops a target that was freed (had it: %s)" % had)
	game.respawn_delay = 2.0
	for w in [green, player, purple]:
		w.reset(c + Vector2(-900, 0))
	_remove_bot(ai)


func _test_rolls_pruned_not_wiped() -> void:
	print("dodge rolls pruned")
	_park_all()
	var ai := _make_bot(blue, "brawler", "normal")
	var live := _fake_projectile_at(blue, green)
	var kept: Array = ai._roll(live)
	for i in 70:
		var gone := Object.new() # a projectile long gone
		ai._rolls[gone.get_instance_id()] = [true, true]
		gone.free()
	var other := _fake_projectile_at(blue, green)
	ai._roll(other)
	_check(ai._rolls.get(live.get_instance_id()) == kept and ai._rolls.size() <= 3,
		"rolls of live projectiles survive, dead ones go (%d left)" % ai._rolls.size())
	live.free()
	other.free()
	_remove_bot(ai)


## The warning ring is treated as lava: a bot standing in it walks inside
## before it melts.
func _test_leaves_doomed_ring() -> void:
	print("leaves the doomed ring")
	_park_all()
	var ai := _make_bot(blue, "survivor", "normal")
	var edge := (_edge_east() - c).length()
	_place(blue, c + Vector2(edge - 2.5 * arena.tile_size, 0))
	await _frames(2)
	arena.shrink_delay = 2.0
	arena.shrink_warning = 2.0
	arena.shrink_step_tiles = 5.0
	arena.shrink_speed = 10.0
	arena.shrinks = true
	arena.restart_shrink_timer()
	var burnt := 0
	var t := 0.0
	while t < 3.0:
		await _frames(1)
		t += 1.0 / 60.0
		if blue.on_lava:
			burnt += 1
	arena.shrinks = false
	arena.regrow()
	_check(burnt == 0, "never on lava while the edge creeps in (%d frames)" % burnt)
	_remove_bot(ai)


## A far-away sniper that keeps hitting the bot becomes its target, even with
## a closer enemy around (stops the Caster picking everyone off for free).
func _test_retaliates_against_attacker() -> void:
	print("retaliates")
	_park_all()
	var ai := _make_bot(blue, "brawler", "normal")
	_place(blue, c)
	_place(purple, c + Vector2(120, 0))
	_place(green, c + Vector2(-380, 0))
	await _frames(2)
	_check(ai._pick_target() == purple, "nearest enemy first")
	_check(blue.last_attacker == null, "no attacker yet")
	blue.take_damage(5.0, green)
	_check(blue.last_attacker == green, "take_damage remembers who hit")
	ai.target = null
	_check(ai._pick_target() == green, "turns on whoever just hit it")
	_remove_bot(ai)


# --- helpers -----------------------------------------------------------------

## v0.10: the Brawler waits for an opening before charging. Give `w` one a
## player would see (hurt + just blinked), then put it at `at`.
func _open_up(w: Wizard, at: Vector2) -> void:
	await _frames(2) # the bot's memory starts watching a frame after it's added
	_place(w, at)
	(w.get_spell("W") as Spell).cooldown_left = 0.0
	w.cast("W", at + Vector2(0, 40))
	await _frames(20)
	w.global_position = at
	w.health = 30.0

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
