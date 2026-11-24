extends SceneTree
## Plays a short scripted fight (~10 s) for recording with Godot's Movie Maker:
##   godot --path . --write-movie recordings/demo.avi --fixed-fps 30 -s tools/record_demo.gd
## Without --write-movie it just plays the demo in a window.

var game: Node
var player: Wizard
var blue: Wizard
var green: Wizard


func _init() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.bot_ai = false
	game.shrink_arena = false
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(2)
	var arena: Arena = game.get_node("Arena")
	player = game.get_node("Wizards/Player")
	blue = game.get_node("Wizards/BotBlue")
	green = game.get_node("Wizards/BotGreen")
	game.get_node("Wizards/Player/PlayerController").process_mode = Node.PROCESS_MODE_DISABLED

	# Stage it by the south shore so the lava is in shot.
	var c := arena.get_center()
	var edge := c
	for d in range(0, 3000, 8):
		if arena.is_lava_at(c + Vector2(0, d)):
			edge = c + Vector2(0, d)
			break
	player.global_position = edge + Vector2(-40, -310)
	blue.global_position = edge + Vector2(0, -175)
	green.global_position = edge + Vector2(-230, -260)
	blue.health = 24.0 # fireball + lightning leave it nearly dead for the lava
	blue.health_changed.emit(blue.health, blue.max_health)
	var cam: ArenaCamera = arena.camera
	cam.global_position = player.global_position
	cam.reset_smoothing()

	await _seconds(0.6)
	player.move_target = edge + Vector2(0, -300) # stroll into position
	await _seconds(0.6)
	player.cast("Q", blue.global_position) # fireball pushes blue toward the lava
	await _seconds(1.4)
	player.cast("W", blue.global_position) # blink after it
	await _seconds(0.5)
	player.cast("E", blue.global_position) # lightning: into the lava
	await _seconds(0.25)
	cam.target = blue # follow it in to watch it burn
	await _seconds(1.5)
	cam.target = player
	await _seconds(0.3)
	green.cast("Q", player.global_position) # green fights back...
	await _seconds(0.2)
	player.cast("R", green.global_position) # ...into a shield, reflected
	await _seconds(1.1)
	green.cast("E", player.global_position) # lightning splashes off the shield
	await _seconds(1.0)
	player.move_target = player.global_position + Vector2(-60, 0)
	await _seconds(0.5)
	player.get_spell("Q").cooldown_left = 0.0
	player.cast("Q", green.global_position)
	await _seconds(1.5)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(s: float) -> void:
	await create_timer(s).timeout
