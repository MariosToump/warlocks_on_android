extends Node2D
## Top-level game scene: the player plus three AI bots.
##
## Match: rounds of last-wizard-standing; first to `wins_to_take_match`
## round wins takes the match. Each round: everyone is placed on a ring,
## a short countdown (nobody can act), then the fight; the platform shrinks
## so rounds always end. The dead stay dead until the next round.
##
## With `rounds` off (tests, AI sim) it's an endless free-for-all where the
## dead respawn after `respawn_delay`.

signal round_started(number: int)
signal fight_started
signal round_ended(winner: Wizard) ## null = draw
signal match_ended(winner: Wizard)
signal kill_scored(killer: Wizard, victim: Wizard)

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

enum State { FREE, COUNTDOWN, FIGHT, ROUND_OVER, MATCH_OVER }

## False = endless free-for-all with respawns (tests and the AI sim).
@export var rounds := true
@export var wins_to_take_match := 5
@export var countdown_time := 3.0
@export var round_over_time := 3.0
## Everyone starts each round on a flat ellipse this wide (radius, px) and
## half as tall, so the whole field fits on screen at the follow zoom.
@export var spawn_distance := 260.0
## A death counts as a kill for whoever hit the victim within this many seconds
## (so knocking someone into lava counts).
@export var kill_credit_window := 10.0
## Seconds after the player dies before the camera moves to someone alive.
@export var spectate_delay := 1.5
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
## Read zoom / bot difficulty / wins per match / vibration from GameSettings
## (tests turn this off so their own values stick).
@export var apply_settings := true

@onready var arena: Arena = $Arena
@onready var wizards: Node2D = $Wizards
@onready var player: Wizard = $Wizards/Player
@onready var touch: TouchControls = $HUD/TouchControls
@onready var round_hud: RoundHud = $HUD/RoundHud

var state := State.FREE
var round_number := 0
## Seconds left in COUNTDOWN / ROUND_OVER.
var state_left := 0.0
var all_wizards: Array[Wizard] = []
var wins := {} ## Wizard -> round wins this match
var kills := {} ## Wizard -> kills this match
var round_winner: Wizard = null
var match_winner: Wizard = null

var _lava_label: Label
var _player_dead_for := 0.0
var _last_lava_buzz := -10.0
## Vibrations sent (tests read this; desktop has no motor).
var haptic_count := 0

var arrows: EnemyArrows
var minimap: Minimap
var damage_numbers: DamageNumbers
var vignette: DangerVignette
var pause_menu: PauseMenu


func _ready() -> void:
	if apply_settings:
		GameSettings.ensure_loaded()
		follow_zoom = GameSettings.zoom_value()
		bot_difficulty = GameSettings.difficulty as Difficulty
		wins_to_take_match = GameSettings.wins_to_take_match
	arena.shrinks = shrink_arena
	arena.regrows = not rounds # rounds end in sudden death instead
	_lava_label = _make_lava_label()
	# Arena builds its map in its own _ready (children are ready first).
	_add_wizard(player, arena.get_center())
	if spawn_bots:
		for i in BOTS.size():
			var offset := Vector2.from_angle(-PI / 2.0 + i * TAU / BOTS.size()) * bot_spawn_distance
			_spawn_bot(BOTS[i][0], BOTS[i][1], offset)

	touch.wizard = player
	round_hud.game = self
	round_hud.play_again_pressed.connect(start_match)
	_build_hud_extras()
	player.damaged.connect(_on_player_damaged)

	arena.camera.target = player
	arena.camera.set_design_zoom(follow_zoom)
	arena.camera.global_position = player.global_position
	arena.camera.reset_smoothing()

	for w in all_wizards:
		wins[w] = 0
		kills[w] = 0
	if rounds:
		start_match()
	else:
		round_hud.visible = false


func _add_wizard(w: Wizard, at: Vector2) -> void:
	w.arena = arena
	w.global_position = at
	w.health_changed.emit(w.health, w.max_health)
	w.died.connect(_on_wizard_died)
	w.damaged.connect(func(amount: float, source: Wizard):
		if source != null and damage_numbers:
			damage_numbers.add(w, amount))
	all_wizards.append(w)


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


## Short name for the HUD: "You", "Blue", ...
func display_name(w: Wizard) -> String:
	if w == player:
		return "You"
	return Wizard.TeamColor.keys()[w.team_color].capitalize()


func alive_wizards() -> Array[Wizard]:
	var out: Array[Wizard] = []
	for w in all_wizards:
		if w.alive:
			out.append(w)
	return out


# --- match flow -------------------------------------------------------------

## Scores to zero, then round 1.
func start_match() -> void:
	if apply_settings:
		wins_to_take_match = GameSettings.wins_to_take_match
	for w in all_wizards:
		wins[w] = 0
		kills[w] = 0
	round_number = 0
	match_winner = null
	start_round()


func start_round() -> void:
	round_number += 1
	round_winner = null
	_player_dead_for = 0.0
	_clear_effects()
	arena.shrinks = false
	arena.regrow()
	# Everyone on an ellipse around the middle, facing in; random rotation.
	var c := arena.get_center()
	var a0 := randf() * TAU
	var order := all_wizards.duplicate()
	order.shuffle()
	for i in order.size():
		var w: Wizard = order[i]
		var a := a0 + i * TAU / order.size()
		w.reset(c + Vector2(cos(a), sin(a) * 0.5) * spawn_distance)
		w.face(c)
		for s in w.get_node("Spells").get_children():
			if s is Spell:
				s.cooldown_left = 0.0
		var ai := w.get_node_or_null("AIController") as AIController
		if ai:
			ai.reset()
	_set_controls(false)
	# Countdown: look at the whole field, then glide to the player at "Fight!".
	arena.camera.target = null
	arena.camera.global_position = c
	arena.camera.reset_smoothing()
	state = State.COUNTDOWN
	state_left = countdown_time
	round_started.emit(round_number)


func _begin_fight() -> void:
	state = State.FIGHT
	arena.camera.target = player
	_set_controls(true)
	arena.shrinks = shrink_arena
	arena.restart_shrink_timer()
	fight_started.emit()


func _end_round(winner: Wizard) -> void:
	state = State.ROUND_OVER
	state_left = round_over_time
	round_winner = winner
	if winner:
		wins[winner] += 1
		if wins[winner] >= wins_to_take_match:
			match_winner = winner
	_set_controls(false)
	arena.shrinks = false
	round_ended.emit(winner)


## Player and bot brains on/off (wizards still animate and get knocked about).
func _set_controls(on: bool) -> void:
	touch.locked = not on
	for w in all_wizards:
		w.move_target = null
		w.move_dir = Vector2.ZERO
		w.attack_target = null
		for n in ["PlayerController", "AIController"]:
			var ctl := w.get_node_or_null(n)
			if ctl:
				ctl.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


## Projectiles, bolts and effects left over from the last round.
func _clear_effects() -> void:
	for n in wizards.get_children():
		if not n is Wizard:
			n.queue_free()


func _process(delta: float) -> void:
	_lava_label.text = arena.status_text() if state in [State.FIGHT, State.FREE] else ""
	_lava_label.modulate = Color(1, 0.55, 0.2) if arena.warning_active() else Color(1, 1, 1, 0.85)
	match state:
		State.COUNTDOWN:
			state_left -= delta
			if state_left <= 0.0:
				_begin_fight()
		State.FIGHT:
			# Checked every frame (after physics), so wizards dying on the
			# same tick all count, and none can slip by unnoticed.
			var living := alive_wizards()
			if living.size() <= 1:
				_end_round(living[0] if living.size() == 1 else null)
				return
			_update_spectate(delta)
		State.ROUND_OVER:
			state_left -= delta
			if state_left <= 0.0:
				if match_winner:
					state = State.MATCH_OVER
					match_ended.emit(match_winner)
				else:
					start_round()


## Once the player is out, watch whoever killed them (or anyone alive).
func _update_spectate(delta: float) -> void:
	if player.alive:
		return
	_player_dead_for += delta
	if _player_dead_for < spectate_delay:
		return
	var cam := arena.camera
	var watching := cam.target as Wizard
	if watching != null and watching != player and watching.alive:
		return
	var pick: Wizard = null
	if is_instance_valid(player.last_attacker) and player.last_attacker.alive:
		pick = player.last_attacker
	else:
		var living := alive_wizards()
		if not living.is_empty():
			pick = living[0]
	if pick:
		cam.target = pick


func _on_wizard_died(w: Wizard) -> void:
	var k := w.last_attacker
	var now := Time.get_ticks_msec() / 1000.0
	if is_instance_valid(k) and k != w and now - w.last_hit_at <= kill_credit_window \
			and state in [State.FIGHT, State.FREE]:
		kills[k] = kills.get(k, 0) + 1
		kill_scored.emit(k, w)
	if state == State.FREE:
		_respawn_later(w)


## Endless mode: respawn on safe stone, as far from the living as a few
## random tries allow.
func _respawn_later(w: Wizard) -> void:
	await get_tree().create_timer(respawn_delay).timeout
	if state != State.FREE:
		return
	var best := arena.random_stone_point()
	var best_gap := -1.0
	for i in 8:
		var p := arena.random_stone_point()
		var gap := INF
		for other in all_wizards:
			if other != w and other.alive:
				gap = minf(gap, p.distance_to(other.global_position))
		if gap > best_gap:
			best_gap = gap
			best = p
	w.reset(best)


# --- HUD extras, settings, haptics ---------------------------------------------

## Danger vignette (under everything), then arrows, damage numbers, minimap,
## and the pause menu on top.
func _build_hud_extras() -> void:
	var hud := $HUD
	vignette = DangerVignette.new()
	vignette.name = "DangerVignette"
	vignette.game = self
	hud.add_child(vignette)
	hud.move_child(vignette, 0)
	damage_numbers = DamageNumbers.new()
	damage_numbers.name = "DamageNumbers"
	damage_numbers.game = self
	hud.add_child(damage_numbers)
	hud.move_child(damage_numbers, 1)
	arrows = EnemyArrows.new()
	arrows.name = "EnemyArrows"
	arrows.game = self
	hud.add_child(arrows)
	minimap = Minimap.new()
	minimap.name = "Minimap"
	minimap.game = self
	hud.add_child(minimap)
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -Minimap.DIAMETER - 12.0
	minimap.offset_right = -12.0
	minimap.offset_top = 12.0
	minimap.offset_bottom = 12.0 + Minimap.DIAMETER
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	pause_menu.game = self
	hud.add_child(pause_menu)


## Settings that can change mid-match (from the pause menu).
func apply_live_settings() -> void:
	follow_zoom = GameSettings.zoom_value()
	arena.camera.set_design_zoom(follow_zoom)
	bot_difficulty = GameSettings.difficulty as Difficulty
	for w in all_wizards:
		var ai := w.get_node_or_null("AIController") as AIController
		if ai:
			ai.profile = PROFILES[bot_difficulty]


func _on_player_damaged(_amount: float, source: Wizard) -> void:
	if apply_settings and not GameSettings.haptics:
		return
	if source != null:
		_buzz(40)
	else:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_lava_buzz >= 0.5:
			_last_lava_buzz = now
			_buzz(25)


func _buzz(ms: int) -> void:
	haptic_count += 1
	Input.vibrate_handheld(ms)


func _notification(what: int) -> void:
	# Android back button: pause / resume instead of quitting.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and pause_menu:
		pause_menu.toggle()


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
