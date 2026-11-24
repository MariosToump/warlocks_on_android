extends Node2D
## Top-level game scene: the player plus three AI bots, free-for-all.
## The platform shrinks over time. Rounds and scoring come in milestone 6;
## until then the dead respawn.

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
## The platform shrinks over time (tests turn this off).
@export var shrink_arena := true

@onready var arena: Arena = $Arena
@onready var wizards: Node2D = $Wizards
@onready var player: Wizard = $Wizards/Player
@onready var touch: TouchControls = $HUD/TouchControls

var _lava_label: Label


func _ready() -> void:
	arena.shrinks = shrink_arena
	_lava_label = _make_lava_label()
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


## Temporary until rounds exist (milestone 6): respawn on safe stone, as far
## from the living as a few random tries allow.
func _on_wizard_died(w: Wizard) -> void:
	await get_tree().create_timer(respawn_delay).timeout
	var best := arena.random_stone_point()
	var best_gap := -1.0
	for i in 8:
		var p := arena.random_stone_point()
		var gap := INF
		for other in get_tree().get_nodes_in_group("wizards"):
			if other != w and other.alive:
				gap = minf(gap, p.distance_to(other.global_position))
		if gap > best_gap:
			best_gap = gap
			best = p
	w.reset(best)


func _process(_delta: float) -> void:
	_lava_label.text = arena.status_text()
	_lava_label.modulate = Color(1, 0.55, 0.2) if arena.warning_active() else Color(1, 1, 1, 0.85)


## Top-centre line: "Lava rises in 12" etc.
func _make_lava_label() -> Label:
	var l := Label.new()
	l.name = "LavaTimer"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l.offset_left = -200
	l.offset_right = 200
	l.offset_top = 10
	l.offset_bottom = 40
	return l
