extends Node2D
## Top-level game scene: the player plus two training dummies (stand-ins
## until the AI bots in milestone 5). Rounds and scoring come later.

const WIZARD := preload("res://scenes/wizard.tscn")

@export var respawn_delay := 2.0
@export var follow_zoom := 1.5 ## camera zoom while following the player
@export var spawn_dummies := true

@onready var arena: Arena = $Arena
@onready var wizards: Node2D = $Wizards
@onready var player: Wizard = $Wizards/Player
@onready var touch: TouchControls = $HUD/TouchControls

var _spawns := {} # Wizard -> spawn position


func _ready() -> void:
	# Arena builds its map in its own _ready (children are ready first).
	_add_wizard(player, arena.get_center())
	if spawn_dummies:
		_spawn_dummy(Wizard.TeamColor.BLUE, Vector2(160, -40))
		_spawn_dummy(Wizard.TeamColor.GREEN, Vector2(-150, 80))

	touch.wizard = player

	arena.camera.target = player
	arena.camera.zoom = Vector2(follow_zoom, follow_zoom)
	arena.camera.global_position = player.global_position
	arena.camera.reset_smoothing()


func _add_wizard(w: Wizard, at: Vector2) -> void:
	w.arena = arena
	w.global_position = at
	_spawns[w] = at
	w.health_changed.emit(w.health, w.max_health)
	w.died.connect(_on_wizard_died)


func _spawn_dummy(color: Wizard.TeamColor, offset: Vector2) -> Wizard:
	var d: Wizard = WIZARD.instantiate()
	d.name = "Dummy%s" % Wizard.TeamColor.keys()[color].capitalize()
	d.team_color = color
	wizards.add_child(d)
	_add_wizard(d, arena.get_center() + offset)
	return d


## Temporary until rounds exist (milestone 6): respawn where they started.
func _on_wizard_died(w: Wizard) -> void:
	await get_tree().create_timer(respawn_delay).timeout
	w.reset(_spawns[w])
