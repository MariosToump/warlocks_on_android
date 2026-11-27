extends "res://tools/shots/shot_base.gd"
## Every spell in turn: the player casts at a dummy (blue) 220 px east.

func _init() -> void:
	setup()
	_run.call_deferred()


func _run() -> void:
	await frames(2)
	grab()
	for w in [green, purple]:
		w.global_position = c + Vector2(2000, 2000)
	player.global_position = c
	cam_on(player)
	var spots := [["Q", ""], ["E", ""], ["A", ""], ["W", ""], ["R", ""], ["", "homing"], ["", "boomerang"],
			["", "swap"], ["", "meteor"], ["", "well"], ["", "rockwall"], ["", "timestop"]]
	for s in spots:
		player.global_position = c
		player.knockback = Vector2.ZERO
		blue.reset(c + Vector2(220, 0))
		blue.health = blue.max_health
		await seconds(0.3)
		var slot: String = s[0]
		if slot == "":
			slot = give(player, s[1])
		var sp := player.get_spell(slot)
		if sp:
			sp.cooldown_left = 0.0
		var at := blue.global_position
		if slot == "A":
			blue.global_position = c + Vector2(40, 0)
			at = blue.global_position
		if s[1] == "timestop":
			blue.cast("Q", player.global_position) # something to freeze
			await seconds(0.15)
			at = c + Vector2(110, 0)
		if slot == "R":
			player.cast("R", at)
			await seconds(0.15)
			blue.cast("Q", player.global_position) # reflect it
		else:
			player.cast(slot, at)
		await seconds(1.6 if s[1] in ["meteor", "well", "timestop", "boomerang"] else 1.1)
	quit()
