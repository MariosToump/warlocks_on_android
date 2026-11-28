extends SceneTree
## Screenshot of the PC bar mid-fight (a spell cooling down, a bought spell,
## the tooltip over Q):  godot --path . -s tools/shots/pc_bar.gd -- <out.png>

var game: Node


func _init() -> void:
	Platform.forced = Platform.Mode.PC
	game = load("res://scenes/game.tscn").instantiate()
	game.apply_settings = false
	game.title_screen = false
	game.countdown_time = 0.3
	game.shop_time = 0.02
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	var out := "user://pc_bar.png"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out = args[0]
	while game.state != game.State.FIGHT:
		await process_frame
	var p: Wizard = game.player
	game.gold[p] = 100
	Shop.buy_spell(game, p, "homing")
	p.cast("Q", p.global_position + Vector2(150, 0))
	await create_timer(0.6).timeout
	Input.warp_mouse(root.get_final_transform() * game.pc_bar.slot_rect("Q").get_center())
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
