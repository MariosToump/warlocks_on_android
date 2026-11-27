extends "res://tools/shots/shot_base.gd"
## Idle, then walk in all 8 directions (0.8 s each), idle again. Bots parked away.

func _init() -> void:
	setup()
	_run.call_deferred()


func _run() -> void:
	await frames(2)
	grab()
	for w in [blue, green, purple]:
		w.global_position = c + Vector2(-600, -500 + 80 * [blue, green, purple].find(w))
	player.global_position = c
	cam_on(player)
	await seconds(1.2) # idle
	for i in 8:
		player.move_dir = Vector2.from_angle(i * TAU / 8.0)
		await seconds(0.8)
		player.move_dir = Vector2.ZERO
		await seconds(0.25)
	await seconds(1.0)
	quit()
