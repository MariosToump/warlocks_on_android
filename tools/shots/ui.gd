extends "res://tools/shots/shot_base.gd"
## Title, countdown + HUD in a fight, far zoom, the shop, the pause menu, results.

func _init() -> void:
	setup(true, true, true)
	_run.call_deferred()


func _run() -> void:
	await frames(2)
	grab()
	await seconds(2.0) # title
	game.start_from_title()
	await seconds(4.0) # countdown + fight + HUD
	blue.take_damage(40.0, player)
	await seconds(1.0)
	arena.camera.set_design_zoom(GameSettings.ZOOMS.far)
	await seconds(2.0)
	arena.camera.set_design_zoom(GameSettings.ZOOMS.close)
	game.gold[player] = 60
	game.open_shop()
	await seconds(2.0)
	game.close_shop()
	await seconds(1.0)
	game.pause_menu.open()
	await seconds(1.5)
	game.pause_menu.toggle()
	await seconds(0.5)
	game.match_winner = player
	game.state = game.State.MATCH_OVER
	game.match_ended.emit(player)
	await seconds(2.0)
	quit()
