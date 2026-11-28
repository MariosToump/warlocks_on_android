extends SceneTree
## Dark Mirror (2026-11-28, replaces Rock Wall): spells that fly into the
## panes go straight back to their caster at the same speed; the panes cover
## 1/3, 2/3 or all of the ring by level; lightning comes back down its line;
## the wizard's own hitbox is unchanged; it ends on time and when its wizard
## dies; the bots raise it against a spell and don't shoot into one.
##   godot --headless --path . -s tools/test_dark_mirror.gd

const NORMAL := preload("res://ai/profiles/normal.tres")
const CASTER := preload("res://ai/personalities/caster.tres")

var game: Node
var player: Wizard
var blue: Wizard
var arena: Arena
var c: Vector2
var failures := 0


func _init() -> void:
	Platform.forced = Platform.Mode.TOUCH # touch-layer test
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
	c = arena.get_center()
	player.get_node("PlayerController").process_mode = Node.PROCESS_MODE_DISABLED
	for n in ["BotGreen", "BotPurple"]:
		(game.get_node("Wizards/" + n) as Wizard).reset(c + Vector2(-900, 600))
	game.state = game.State.FREE
	_clear()
	game.gold[player] = 100
	Shop.buy_spell(game, player, "mirror")
	var slot := player.slot_of("mirror")
	var spell := player.get_spell(slot) as DarkMirrorSpell
	_check(spell != null and slot == "F", "Dark Mirror bought into F")

	print("level 0: a third of the ring, facing the aim")
	_check(is_equal_approx(spell.arc(), TAU / 3.0), "arc = 1/3")
	spell.level = 1
	_check(is_equal_approx(spell.arc(), TAU * 2.0 / 3.0), "level 1: 2/3")
	spell.level = 2
	_check(is_equal_approx(spell.arc(), TAU), "level 2: the whole ring")
	spell.level = 0

	print("sends a fireball back to its caster, same speed")
	player.reset(c)
	blue.reset(c + Vector2(300, 0))
	await _frames(2)
	spell.release(c + Vector2(100, 0))
	await _frames(1)
	var m := DarkMirror.of(player)
	_check(m != null, "the mirror is up")
	blue.cast("Q", player.global_position)
	await _seconds(0.2)
	var fb := _projectile()
	var speed := fb.speed if fb else 0.0
	await _seconds(0.5)
	_check(is_equal_approx(player.health, player.max_health), "you aren't hit (hp %.0f)" % player.health)
	_check(fb != null and is_instance_valid(fb) and fb.caster == player and fb.direction.x > 0.9,
			"it flies back toward the blue wizard, now yours")
	_check(fb != null and is_instance_valid(fb) and is_equal_approx(fb.speed, speed), "at the same speed (%.0f)" % speed)
	await _seconds(0.8)
	_check(blue.health < blue.max_health, "and hits its caster (blue hp %.0f)" % blue.health)
	_check(blue.last_attacker == player, "the hit is credited to the mirror's wizard")

	print("the uncovered side: the hitbox is the same as without a mirror")
	_clear()
	player.reset(c)
	blue.reset(c + Vector2(-300, 0)) # behind a mirror facing right
	await _frames(2)
	spell.release(c + Vector2(100, 0))
	await _frames(1)
	blue.cast("Q", player.global_position)
	await _seconds(1.0)
	_check(player.health < player.max_health, "a spell from behind a 1/3 mirror still hits you (hp %.0f)" % player.health)
	_check(DarkMirror.of(player).covers_dir(Vector2.RIGHT) and not DarkMirror.of(player).covers_dir(Vector2.LEFT),
			"covers the front, not the back")
	var shape := player.get_node("Shape") as CollisionShape2D
	_check(shape == null or (shape.shape is CircleShape2D and (shape.shape as CircleShape2D).radius < DarkMirror.RADIUS),
			"the wizard's own body shape is untouched")

	print("level 2: the whole ring")
	_clear()
	spell.level = 2
	player.reset(c)
	blue.reset(c + Vector2(-300, 0))
	await _frames(2)
	spell.release(c + Vector2(100, 0)) # aimed away from blue
	await _frames(1)
	blue.cast("Q", player.global_position)
	await _seconds(1.2)
	_check(is_equal_approx(player.health, player.max_health), "a spell from behind bounces too")
	_check(blue.health < blue.max_health, "and goes back to blue")
	spell.level = 0

	print("homing orb")
	_clear()
	game.gold[blue] = 100
	Shop.buy_spell(game, blue, "homing")
	player.reset(c)
	blue.reset(c + Vector2(350, 0))
	await _frames(2)
	spell.release(c + Vector2(100, 0))
	await _frames(1)
	blue.get_spell(blue.slot_of("homing")).release(player.global_position)
	var t := 0
	while blue.health == blue.max_health and t < 240:
		await _frames(1)
		t += 1
	_check(is_equal_approx(player.health, player.max_health) and blue.health < blue.max_health, "a homing orb comes back too")
	Shop.sell_spell(game, blue, "homing")

	print("lightning comes back down its line")
	_clear()
	player.reset(c)
	blue.reset(c + Vector2(250, 0))
	await _frames(2)
	spell.release(c + Vector2(100, 0))
	await _frames(1)
	blue.get_spell("E").release(player.global_position)
	await _frames(2)
	_check(is_equal_approx(player.health, player.max_health), "the bolt stops on the glass")
	_check(blue.health < blue.max_health and blue.knockback.x > 0.0, "and hits blue, pushing it away (hp %.0f)" % blue.health)

	print("the caster died: it just turns around")
	_clear()
	player.reset(c)
	blue.reset(c + Vector2(300, 0))
	await _frames(2)
	spell.release(c + Vector2(100, 0))
	await _frames(1)
	blue.cast("Q", player.global_position)
	await _seconds(0.2)
	blue.take_damage(1000.0)
	await _seconds(0.7)
	fb = _projectile()
	_check(is_equal_approx(player.health, player.max_health) and (fb == null or fb.direction.x > 0.9), "no error, it flies back out")
	blue.reset(c + Vector2(300, 0))

	print("ends")
	_clear()
	player.reset(c)
	await _frames(2)
	spell.release(c + Vector2(100, 0))
	await _seconds(spell.duration_by_level[0] + 0.1)
	_check(DarkMirror.of(player) == null, "gone after %.1f s" % spell.duration_by_level[0])
	spell.release(c + Vector2(100, 0))
	await _frames(2)
	player.take_damage(1000.0)
	await _frames(2)
	_check(DarkMirror.of(player) == null, "gone when its wizard dies")
	player.reset(c)

	print("bots")
	_clear()
	blue.reset(c)
	player.reset(c + Vector2(400, 0))
	game.gold[blue] = 100
	Shop.buy_spell(game, blue, "mirror")
	var ai := AIController.new()
	ai.personality = CASTER
	ai.profile = NORMAL
	blue.add_child(ai)
	ai.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(2)
	player.cast("Q", blue.global_position)
	await _seconds(0.35)
	ai._danger = _projectile()
	_check(ai._danger != null, "a fireball is coming at the bot")
	if ai._danger:
		ai._rolls[ai._danger.get_instance_id()] = [true, false, 0.0]
	_check(ai._score_mirror() > ai._score_dodge(), "it raises the mirror rather than dodge (%.2f vs %.2f)" % [ai._score_mirror(), ai._score_dodge()])
	_clear()
	ai._danger = null
	ai.target = player
	(blue.get_spell("Q") as Spell).cooldown_left = 0.0
	var before := ai._score_fireball()
	player.get_spell(slot).release(blue.global_position)
	await _frames(1)
	_check(before > 0.0 and ai._score_fireball() == 0.0, "and won't throw a fireball into one (%.2f before)" % before)
	ai.free()

	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _projectile() -> Projectile:
	for n in get_nodes_in_group("projectiles"):
		if n is Projectile and not n.is_queued_for_deletion():
			return n
	return null


func _clear() -> void:
	for g in ["props", "projectiles", "mirrors"]:
		for p in get_nodes_in_group(g):
			p.queue_free()
	for w in [player, blue]:
		for s in w.get_node("Spells").get_children():
			(s as Spell).cooldown_left = 0.0


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(s: float) -> void:
	await _frames(roundi(s * 60.0))
