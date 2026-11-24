extends Node2D
## Top-level game scene: the player plus three AI bots, free-for-all.
## Rounds and scoring come in milestone 6; until then the dead respawn.

const WIZARD := preload("res://scenes/wizard.tscn")

enum Difficulty { EASY, NORMAL, HARD }
const PROFILES := {
	Difficulty.EASY: preload("res://ai/profiles/easy.tres"),
	Difficulty.NORMAL: preload("res://ai/profiles/normal.tres"),
	Difficulty.HARD: preload("res://ai/profiles/hard.tres"),
}
## Team colour -> personality of the bot wearing it.
const BOTS := [
	[Wizard.TeamColor.BLUE, preload("res://ai/personalities/brawler.tres")],
	[Wizard.TeamColor.GREEN, preload("res://ai/personalities/caster.tres")],
	[Wizard.TeamColor.PURPLE, preload("res://ai/personalities/trickster.tres")],
]

@export var respawn_delay := 2.0
@export var follow_zoom := 2.0 ## camera zoom while following the player (snapped to whole pixels)
@export var spawn_bots := true
@export var bot_difficulty := Difficulty.NORMAL
## False = bots spawn as passive dummies with no AIController (tests).
@export var bot_ai := true
@export var bot_spawn_distance := 250.0
## Draw each bot's current action and target line.
@export var bot_debug := false

@onready var arena: Arena = $Arena
@onready var wizards: Node2D = $Wizards
@onready var player: Wizard = $Wizards/Player
@onready var touch: TouchControls = $HUD/TouchControls

var _spawns := {} # Wizard -> spawn position


func _ready() -> void:
	# Arena builds its map in its own _ready (children are ready first).
	_add_wizard(player, arena.get_center())
	if spawn_bots:
		for i in BOTS.size():
			var offset := Vector2.from_angle(-PI / 2.0 + i * TAU / BOTS.size()) * bot_spawn_distance
			_spawn_bot(BOTS[i][0], BOTS[i][1], offset)

	touch.wizard = player

	arena.camera.target = player
	arena.camera.set_design_zoom(follow_zoom)
	arena.camera.global_position = player.global_position
	arena.camera.reset_smoothing()


func _add_wizard(w: Wizard, at: Vector2) -> void:
	w.arena = arena
	w.global_position = at
	_spawns[w] = at
	w.health_changed.emit(w.health, w.max_health)
	w.died.connect(_on_wizard_died)


func _spawn_bot(color: Wizard.TeamColor, personality: AIPersonality, offset: Vector2) -> Wizard:
	var w: Wizard = WIZARD.instantiate()
	w.name = "Bot%s" % Wizard.TeamColor.keys()[color].capitalize()
	w.team_color = color
	if bot_ai:
		var ai := AIController.new()
		ai.name = "AIController"
		ai.profile = PROFILES[bot_difficulty]
		ai.personality = personality
		ai.debug_draw = bot_debug
		w.add_child(ai)
	wizards.add_child(w)
	_add_wizard(w, arena.get_center() + offset)
	return w


## Temporary until rounds exist (milestone 6): respawn where they started.
func _on_wizard_died(w: Wizard) -> void:
	await get_tree().create_timer(respawn_delay).timeout
	w.reset(_spawns[w])
