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
signal shop_opened
signal shop_closed

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

enum State { FREE, COUNTDOWN, FIGHT, ROUND_OVER, SHOP, MATCH_OVER, TITLE }

## False = endless free-for-all with respawns (tests and the AI sim).
@export var rounds := true
@export var wins_to_take_match := 3
@export var countdown_time := 2.0
@export var round_over_time := 2.0
## Seconds the shop stays open between rounds (Ready closes it sooner).
@export var shop_time := 10.0
## Gold after every round: everyone gets the base, plus per kill that round,
## plus the round winner's bonus.
@export var gold_per_round := 10
@export var gold_per_kill := 5
@export var gold_for_win := 5
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
## Screen shake and hit-stop (the playtest harness turns them off).
@export var feel_effects := true
## Rocks scattered on the island each round: [boulders, pillars].
@export var props_per_round := Vector2i(3, 2)
## Start on the title menu over a bots-only fight (tests turn this off).
@export var title_screen := true
## Title screen: the camera follows one bot, switching every this many seconds.
@export var title_camera_time := 8.0

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
var gold := {} ## Wizard -> gold to spend in the shop
var round_kills := {} ## Wizard -> kills this round (for gold)
var round_winner: Wizard = null
## True for the round that started without a shop (the player had no gold).
var shop_skipped := false
## The dead player's ghost during a fight (null otherwise).
var ghost: Ghost
var _hit_stop_token := 0
var _last_phase := -1
var match_winner: Wizard = null

var _lava_label: Label
var _player_dead_for := 0.0
var _last_lava_buzz := -10.0
var _last_beep := -1
## Vibrations sent (tests read this; desktop has no motor).
var haptic_count := 0

var arrows: EnemyArrows
var minimap: Minimap
var damage_numbers: DamageNumbers
var vignette: DangerVignette
var pause_menu: PauseMenu
var shop_panel: ShopPanel
var title_menu: TitleMenu
var _title_watch_left := 0.0
var _player_layer := 0
var _player_mask := 0
## False on PC (keyboard + mouse): the touch layer is off (Platform.touch()).
var touch_mode := true


func _ready() -> void:
	Platform.apply()
	touch_mode = Platform.touch()
	touch.enabled = touch_mode
	if not touch_mode and apply_settings:
		GameSettings.ensure_loaded()
		GameSettings.apply_window()
	if apply_settings:
		GameSettings.ensure_loaded()
		follow_zoom = GameSettings.zoom_value()
		bot_difficulty = GameSettings.difficulty as Difficulty
		wins_to_take_match = GameSettings.wins_to_take_match
		touch.touchpad = GameSettings.move_mode == "touchpad"
		arena.set_heat_haze(GameSettings.heat_haze)
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
	round_hud.menu_pressed.connect(enter_title)
	_build_hud_extras()
	player.damaged.connect(_on_player_damaged)
	if apply_settings:
		Sfx.apply_settings()

	arena.camera.target = player
	arena.camera.set_design_zoom(follow_zoom)
	arena.camera.global_position = player.global_position
	arena.camera.reset_smoothing()
	arena.camera.reset_physics_interpolation() # no first frame drawn from the old spot (all lava)

	for w in all_wizards:
		wins[w] = 0
		kills[w] = 0
		gold[w] = 0
		round_kills[w] = 0
	if rounds and title_screen:
		enter_title()
	elif rounds:
		Sfx.music("music_fight")
		start_match()
	else:
		Sfx.music("music_fight")
		round_hud.visible = false


func _add_wizard(w: Wizard, at: Vector2) -> void:
	w.arena = arena
	w.global_position = at
	w.health_changed.emit(w.health, w.max_health)
	w.died.connect(_on_wizard_died)
	w.died.connect(func(_w): Sfx.play_at("death", w.global_position))
	w.damaged.connect(func(amount: float, source: Wizard):
		if source != null:
			Sfx.play_at("hurt", w.global_position, -3.0)
			if damage_numbers:
				damage_numbers.add(w, amount, source)
			_feel_hit(w, amount, source))
	w.died.connect(_feel_death)
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

# --- title screen -------------------------------------------------------------

## Title menu over a bots-only brawl: the player is parked out of the game,
## bots fight and respawn, the camera wanders from bot to bot.
func enter_title() -> void:
	get_tree().paused = false
	state = State.TITLE
	_clear_effects()
	arena.shrinks = false
	arena.regrow()
	_park_player(true)
	for w in all_wizards:
		if w == player:
			continue
		w.reset(arena.random_stone_point())
		var ai := w.get_node_or_null("AIController") as AIController
		if ai:
			ai.reset()
	# Watch a bot from the first frame (the parked player is out in the lava:
	# visual review 2026-11-27 saw a screen of lava before the camera moved).
	var bots := all_wizards.filter(func(w): return w != player)
	if not bots.is_empty():
		var first: Wizard = bots.pick_random()
		arena.camera.target = first
		arena.camera.global_position = first.global_position
		arena.camera.reset_smoothing()
		arena.camera.reset_physics_interpolation()
		_title_watch_left = title_camera_time
	_set_controls(true)
	touch.locked = true
	touch.release_all()
	touch.visible = false
	round_hud.visible = false
	shop_panel.visible = false
	minimap.visible = false
	pause_menu.set_pause_button(false)
	title_menu.visible = true
	_title_watch_left = 0.0
	Sfx.music("music_title")


## Play: the player joins, a new match starts.
func start_from_title() -> void:
	title_menu.visible = false
	touch.visible = touch_mode
	_park_player(false)
	round_hud.visible = true
	minimap.visible = true
	pause_menu.set_pause_button(true)
	Sfx.music("music_fight")
	start_match()


func _park_player(parked: bool) -> void:
	if parked:
		if player.collision_layer != 0:
			_player_layer = player.collision_layer
			_player_mask = player.collision_mask
		player.collision_layer = 0
		player.collision_mask = 0
		player.remove_from_group("wizards")
		player.visible = false
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.global_position = arena.get_bounds().position + Vector2(40, 40)
	else:
		if _player_layer != 0:
			player.collision_layer = _player_layer
			player.collision_mask = _player_mask
		if not player.is_in_group("wizards"):
			player.add_to_group("wizards")
		player.visible = true
		player.process_mode = Node.PROCESS_MODE_INHERIT


func _update_title_camera(delta: float) -> void:
	_title_watch_left -= delta
	var cam := arena.camera
	var watching := cam.target as Wizard
	if _title_watch_left > 0.0 and watching != null and watching != player and watching.alive:
		return
	var bots := alive_wizards().filter(func(w): return w != player and w != watching)
	if bots.is_empty():
		return
	cam.target = bots.pick_random()
	_title_watch_left = title_camera_time


## Scores to zero, then round 1.
func start_match() -> void:
	if apply_settings:
		wins_to_take_match = GameSettings.wins_to_take_match
	for w in all_wizards:
		wins[w] = 0
		w.match_wins = 0
		kills[w] = 0
		gold[w] = 0
		Shop.clear(w)
	round_number = 0
	match_winner = null
	shop_skipped = false
	start_round()


func start_round() -> void:
	round_number += 1
	round_winner = null
	_player_dead_for = 0.0
	for w in all_wizards:
		round_kills[w] = 0
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
	_spawn_props()
	_set_controls(false)
	# Countdown: look at the whole field, then glide to the player at "Burn!".
	arena.camera.target = null
	arena.camera.global_position = c
	arena.camera.reset_smoothing()
	arena.camera.reset_physics_interpolation() # no first frame drawn from the old spot (all lava)
	state = State.COUNTDOWN
	state_left = countdown_time
	_last_beep = -1
	round_started.emit(round_number)


## Boulders and pillars on random stone, clear of the wizards and each
## other (the old ones went with _clear_effects).
func _spawn_props() -> void:
	var placed: Array[Vector2] = []
	var kinds: Array = []
	for i in props_per_round.x:
		kinds.append(Prop.Kind.BOULDER)
	for i in props_per_round.y:
		kinds.append(Prop.Kind.PILLAR)
	for k in kinds:
		for attempt in 30:
			var p := arena.random_stone_point()
			var ok := true
			for w in all_wizards:
				if w.global_position.distance_to(p) < 110.0:
					ok = false
			for q in placed:
				if q.distance_to(p) < 120.0:
					ok = false
			if ok:
				placed.append(p)
				wizards.add_child(Prop.make(k, p, arena))
				break


func _begin_fight() -> void:
	state = State.FIGHT
	Sfx.play("fight")
	arena.camera.target = player
	_set_controls(true)
	arena.shrinks = shrink_arena
	arena.restart_shrink_timer()
	fight_started.emit()


func _end_round(winner: Wizard) -> void:
	state = State.ROUND_OVER
	state_left = round_over_time
	round_winner = winner
	_remove_ghost()
	if winner:
		wins[winner] += 1
		winner.match_wins = wins[winner]
		if wins[winner] >= wins_to_take_match:
			match_winner = winner
	_set_controls(false)
	arena.shrinks = false
	if match_winner:
		Sfx.play("match_win" if match_winner == player else "match_lose")
	else:
		Sfx.play("win" if winner == player else "lose")
	round_ended.emit(winner)


## Between rounds: pay everyone, let the bots spend, then the player gets
## `shop_time` seconds (or until Ready).
func open_shop() -> void:
	for w in all_wizards:
		gold[w] = gold.get(w, 0) + gold_per_round + round_kills.get(w, 0) * gold_per_kill 				+ (gold_for_win if w == round_winner else 0)
	for w in all_wizards:
		if w != player:
			Shop.bot_shop(self, w)
	if not Shop.can_shop(self, player):
		shop_skipped = true # nothing to buy: straight on (the HUD says why)
		start_round()
		return
	state = State.SHOP
	state_left = shop_time
	Sfx.muffle_music(true)
	shop_opened.emit()


## Ready (or time's up): next round.
func close_shop() -> void:
	if state != State.SHOP:
		return
	shop_closed.emit()
	Sfx.muffle_music(false)
	shop_skipped = false
	start_round()


## Gold this round's result pays `w` (shown in the shop).
func round_income(w: Wizard) -> int:
	return gold_per_round + round_kills.get(w, 0) * gold_per_kill + (gold_for_win if w == round_winner else 0)


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
	_remove_ghost()
	for n in get_tree().get_nodes_in_group("craters"):
		n.queue_free()
	for n in wizards.get_children():
		if not n is Wizard:
			n.queue_free()


func _process(delta: float) -> void:
	Sfx.loop("lava", player.alive and player.on_lava and state in [State.FIGHT, State.FREE])
	_lava_label.text = arena.status_text() if state in [State.FIGHT, State.FREE] else ""
	_lava_label.modulate = Color(1, 0.55, 0.2) if arena.warning_active() else Color(1, 1, 1, 0.85)
	match state:
		State.TITLE:
			_update_title_camera(delta)
		State.COUNTDOWN:
			var beep := ceili(state_left)
			if beep != _last_beep:
				_last_beep = beep
				Sfx.play("beep")
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
			_feel_lava(delta)
			_feel_heartbeat(delta)
		State.ROUND_OVER:
			state_left -= delta
			if state_left <= 0.0:
				if match_winner:
					state = State.MATCH_OVER
					match_ended.emit(match_winner)
				else:
					open_shop()
		State.SHOP:
			state_left -= delta
			if state_left <= 0.0:
				close_shop()


## Once the player is out (after `spectate_delay`), they float on as a ghost
## until the round ends; the camera follows the ghost.
func _update_spectate(delta: float) -> void:
	if player.alive or ghost != null:
		return
	_player_dead_for += delta
	if _player_dead_for < spectate_delay:
		return
	ghost = Ghost.new()
	ghost.name = "Ghost"
	wizards.add_child(ghost)
	ghost.setup(player)
	touch.ghost = ghost
	if not touch_mode: # on phones the joystick steers it (TouchControls)
		_player_ctl_set("ghost", ghost)
	arena.camera.target = ghost


## Hand the ghost / minimap to the keyboard + mouse controller (PC).
func _player_ctl_set(prop: String, value: Variant) -> void:
	var ctl := player.get_node_or_null("PlayerController")
	if ctl:
		ctl.set(prop, value)


func _remove_ghost() -> void:
	if ghost == null:
		return
	if arena.camera.target == ghost:
		arena.camera.target = round_winner if round_winner else player
	touch.ghost = null
	_player_ctl_set("ghost", null)
	player.move_dir = Vector2.ZERO
	ghost.queue_free()
	ghost = null


func _on_wizard_died(w: Wizard) -> void:
	var k := w.last_attacker
	var now := GameClock.now()
	if is_instance_valid(k) and k != w and now - w.last_hit_at <= kill_credit_window \
			and state in [State.FIGHT, State.FREE]:
		kills[k] = kills.get(k, 0) + 1
		round_kills[k] = round_kills.get(k, 0) + 1
		kill_scored.emit(k, w)
		if k == player:
			Sfx.play("kill")
	if state == State.FREE or state == State.TITLE:
		_respawn_later(w)


## Endless mode: respawn on safe stone, as far from the living as a few
## random tries allow.
func _respawn_later(w: Wizard) -> void:
	await get_tree().create_timer(respawn_delay).timeout
	if state != State.FREE and state != State.TITLE:
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


# --- game feel: shake + hit-stop -------------------------------------------------

## A spell or staff hit: shake when the player is hit, a tiny freeze on
## big hits the player takes or lands.
func _feel_hit(w: Wizard, amount: float, source: Wizard) -> void:
	if not feel_effects or not state in [State.FIGHT, State.FREE]:
		return
	if w == player:
		arena.camera.shake(clampf(amount * Feel.HIT_SHAKE_PER_DAMAGE, Feel.HIT_SHAKE_MIN, Feel.HIT_SHAKE_MAX), Feel.HIT_SHAKE_TIME)
	if amount >= Feel.HIT_STOP_DAMAGE and (w == player or source == player):
		hit_stop(Feel.HIT_STOP_HIT)


## A wizard died: shake if it's on screen, freeze a moment if the player
## was in it.
func _feel_death(w: Wizard) -> void:
	if not feel_effects or not state in [State.FIGHT, State.FREE]:
		return
	var view := get_viewport().get_visible_rect().size / arena.camera.zoom
	if w.global_position.distance_to(arena.camera.global_position) < view.length() * 0.5:
		arena.camera.shake(Feel.DEATH_SHAKE, Feel.DEATH_SHAKE_TIME)
	if w == player or w.last_attacker == player:
		hit_stop(Feel.HIT_STOP_DEATH)


## Slow time to a crawl for `real_seconds`, then back to normal. A newer
## call extends it; time always comes back to 1.
func hit_stop(real_seconds: float) -> void:
	if not feel_effects:
		return
	_hit_stop_token += 1
	var token := _hit_stop_token
	Engine.time_scale = Feel.HIT_STOP_SCALE
	await get_tree().create_timer(real_seconds, true, false, true).timeout
	if token == _hit_stop_token:
		Engine.time_scale = 1.0


## Shake gently each time the lava starts creeping in.
func _feel_lava(_delta: float) -> void:
	if arena.phase != _last_phase:
		if feel_effects and state == State.FIGHT and arena.phase in [Arena.Phase.SHRINK, Arena.Phase.FINAL]:
			arena.camera.shake(Feel.LAVA_SHAKE, Feel.LAVA_SHAKE_TIME)
		_last_phase = arena.phase
	# The ground growls once when the warning line appears.
	var warn := arena.warning_active()
	if warn and not _lava_warned and state == State.FIGHT:
		Sfx.play("lava_warn")
	_lava_warned = warn


## A slow heartbeat while the player is under LOW_HEALTH of their health.
const LOW_HEALTH := 0.25
const HEARTBEAT_EVERY := 0.95
var _lava_warned := false
var _heartbeat_left := 0.0


func _feel_heartbeat(delta: float) -> void:
	if not player.alive or player.health > player.max_health * LOW_HEALTH:
		_heartbeat_left = 0.0
		return
	_heartbeat_left -= delta
	if _heartbeat_left <= 0.0:
		_heartbeat_left = HEARTBEAT_EVERY
		Sfx.play("heartbeat", 0.0, 0.0)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


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
	touch.minimap = minimap
	_player_ctl_set("minimap", minimap)
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -Minimap.DIAMETER - 12.0
	minimap.offset_right = -12.0
	minimap.offset_top = 12.0
	minimap.offset_bottom = 12.0 + Minimap.DIAMETER
	shop_panel = ShopPanel.new()
	shop_panel.name = "ShopPanel"
	hud.add_child(shop_panel)
	shop_panel.setup(self)
	shop_opened.connect(func(): round_hud._show_banner(""))
	title_menu = TitleMenu.new()
	title_menu.name = "TitleMenu"
	title_menu.game = self
	title_menu.visible = false
	hud.add_child(title_menu)
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	pause_menu.game = self
	hud.add_child(pause_menu)


## Settings that can change mid-match (from the pause menu).
func apply_live_settings() -> void:
	follow_zoom = GameSettings.zoom_value()
	arena.camera.set_design_zoom(follow_zoom)
	bot_difficulty = GameSettings.difficulty as Difficulty
	touch.touchpad = GameSettings.move_mode == "touchpad"
	arena.set_heat_haze(GameSettings.heat_haze)
	for w in all_wizards:
		var ai := w.get_node_or_null("AIController") as AIController
		if ai:
			ai.profile = PROFILES[bot_difficulty]


func _on_player_damaged(_amount: float, source: Wizard) -> void:
	if apply_settings and not GameSettings.haptics:
		return
	if source != null:
		_buzz(Feel.BUZZ_HIT)
	else:
		var now := GameClock.now()
		if now - _last_lava_buzz >= 0.5:
			_last_lava_buzz = now
			_buzz(Feel.BUZZ_LAVA)


func _buzz(ms: int) -> void:
	haptic_count += 1
	Input.vibrate_handheld(ms)


func _notification(what: int) -> void:
	# Android back button: pause / resume instead of quitting.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and pause_menu:
		if state == State.TITLE and not pause_menu.is_open():
			get_tree().quit() # Back on the title screen leaves the app
		else:
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
