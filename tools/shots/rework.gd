extends "res://tools/shots/shot_base.gd"
## 2026-11-28 rework: Dark Mirror (1/3 then full ring) reflecting fireballs,
## Time Stop freezing a wizard, the bigger Meteor.

func _init() -> void:
	setup()
	_run.call_deferred()


func _run() -> void:
	await frames(2)
	grab()
	for w in [green, purple]:
		w.global_position = c + Vector2(2000, 2000)
	player.reset(c)
	blue.reset(c + Vector2(240, 0))
	cam_on(player)
	var ms := give(player, "mirror")
	var m := player.get_spell(ms) as DarkMirrorSpell
	await seconds(0.3)
	player.cast(ms, blue.global_position)
	await seconds(0.2)
	blue.cast("Q", player.global_position)
	await seconds(1.2)
	m.level = 2
	m.cooldown_left = 0.0
	blue.reset(c + Vector2(-240, 60))
	player.cast(ms, c + Vector2(200, 0))
	await seconds(0.2)
	blue.cast("Q", player.global_position)
	await seconds(1.2)
	Shop.sell_spell(game, player, "mirror")
	var ts := give(player, "timestop")
	blue.reset(c + Vector2(220, 0))
	await seconds(0.2)
	player.cast(ts, blue.global_position)
	await seconds(0.4)
	blue.move_dir = Vector2.UP
	player.cast("E", blue.global_position)
	await seconds(1.4)
	blue.move_dir = Vector2.ZERO
	var mt := give(player, "meteor")
	player.reset(c)
	blue.reset(c + Vector2(260, 0))
	player.get_spell(mt).cooldown_left = 0.0
	player.cast(mt, blue.global_position)
	await seconds(1.8)
	quit()
