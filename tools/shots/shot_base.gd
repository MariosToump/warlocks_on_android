extends SceneTree
## Shared setup for visual-review shots (tools/shots/*.gd). Record with:
##   godot --path . --resolution 1280x720 --write-movie review_frames/<shot>/f.png --fixed-fps 30 -s tools/shots/<shot>.gd

var game: Node
var arena: Arena
var player: Wizard
var blue: Wizard
var green: Wizard
var purple: Wizard
var c: Vector2


func setup(ai := false, rounds := false, title := false) -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.bot_ai = ai
	game.shrink_arena = false
	game.rounds = rounds
	game.apply_settings = false
	game.title_screen = title
	game.countdown_time = 0.5
	root.add_child(game)


func grab() -> void:
	arena = game.get_node("Arena")
	player = game.get_node("Wizards/Player")
	blue = game.get_node("Wizards/BotBlue")
	green = game.get_node("Wizards/BotGreen")
	purple = game.get_node("Wizards/BotPurple")
	var pc := player.get_node_or_null("PlayerController")
	if pc:
		pc.process_mode = Node.PROCESS_MODE_DISABLED
	c = arena.get_center()


func lava_edge(dir: Vector2) -> Vector2:
	for d in range(0, 3000, 8):
		if arena.is_lava_at(c + dir * d):
			return c + dir * d
	return c


func give(w: Wizard, id: String) -> String:
	if Shop.free_slot(w, id) == "":
		for slot in Shop.SHOP_SLOTS:
			Shop._remove_spell(w, slot)
	var node := Node.new()
	node.set_script(Shop.SPELLS[id].script)
	node.name = Shop.free_slot(w, id)
	w.get_node("Spells").add_child(node)
	return String(node.name)


func cam_on(n: Node2D) -> void:
	arena.camera.target = n
	arena.camera.global_position = n.global_position
	arena.camera.reset_smoothing()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func seconds(s: float) -> void:
	await create_timer(s).timeout
