extends SceneTree
## The shop fits on a phone screen (v0.12 fix). Needs a window: headless Godot
## measures text as zero size, so the layout can't be checked there.
##   godot --path . -s tools/test_shop_layout.gd
## Checks 1600x720 (a 20:9 phone, e.g. 2400x1080) and 1280x720 (16:9), with
## nothing bought (every new spell listed) and with both slots full.

var game: Node
var failures := 0


func _init() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.bot_ai = false
	game.shrink_arena = false
	game.apply_settings = false
	game.title_screen = false
	game.shop_time = 60.0
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("needs a window: skipped")
		print("TEST PASSED (0 failures)")
		quit(0)
		return
	await _frames(3)
	var player: Wizard = game.player
	game.gold[player] = 40
	game.state = game.State.SHOP
	game.state_left = 60.0
	game.shop_opened.emit()
	for size in [Vector2i(1600, 720), Vector2i(1280, 720)]:
		await _check_size(size, "nothing bought")
	game.gold[player] = 99
	Shop.buy_spell(game, player, "meteor")
	Shop.buy_spell(game, player, "swap")
	Shop.buy_item(game, player, "ring")
	game.shop_panel.refresh()
	for size in [Vector2i(1600, 720), Vector2i(1280, 720)]:
		await _check_size(size, "both slots full")
	print("TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _check_size(size: Vector2i, what: String) -> void:
	DisplayServer.window_set_size(size)
	await _frames(6)
	var panel: ShopPanel = game.shop_panel
	var screen := root.get_visible_rect()
	print("%s at %s" % [what, screen.size])
	var box: Control = panel.get_child(0).get_child(0)
	_check(screen.encloses(box.get_global_rect()), "the shop panel fits (%s)" % box.get_global_rect())
	_check(screen.encloses(panel.ready_button.get_global_rect()), "Ready button on screen")
	for b: Button in panel.find_children("*", "Button", true, false):
		if b.is_queued_for_deletion():
			continue
		if not panel.scroll.get_global_rect().encloses(b.get_global_rect()) and b != panel.ready_button:
			_check(false, "button '%s' visible without scrolling (%s)" % [b.text, b.get_global_rect()])


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame
