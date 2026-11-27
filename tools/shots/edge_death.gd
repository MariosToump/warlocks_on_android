extends "res://tools/shots/shot_base.gd"
## A hit near the lava edge: knockback trail, burn in the lava, death dissolve.

func _init() -> void:
	setup()
	_run.call_deferred()


func _run() -> void:
	await frames(2)
	grab()
	var e := lava_edge(Vector2.DOWN)
	purple.global_position = c + Vector2(2000, -2000)
	player.global_position = e + Vector2(0, -300)
	blue.global_position = e + Vector2(0, -110)
	green.global_position = e + Vector2(-260, -200)
	blue.health = 30.0
	cam_on(blue)
	await seconds(0.6)
	player.cast("E", blue.global_position)
	await seconds(3.5)
	green.take_damage(500.0, player) # a death on stone too
	await seconds(2.0)
	quit()
