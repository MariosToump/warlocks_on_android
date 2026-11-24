extends Node2D
## Top-level game scene. For now: one player wizard on the arena.
## Rounds, bots and scoring come in later milestones.

@export var respawn_delay := 2.0

@onready var arena: Arena = $Arena
@onready var player: Wizard = $Wizards/Player


func _ready() -> void:
	# Arena builds its map in its own _ready (children are ready first).
	player.arena = arena
	player.global_position = arena.get_center()
	player.health_changed.emit(player.health, player.max_health)
	player.died.connect(_on_wizard_died)
	arena.camera.target = player
	arena.camera.zoom = Vector2.ONE
	arena.camera.global_position = player.global_position
	arena.camera.reset_smoothing()


## Temporary until rounds exist (milestone 6): respawn in the middle.
func _on_wizard_died(w: Wizard) -> void:
	await get_tree().create_timer(respawn_delay).timeout
	w.reset(arena.get_center())
