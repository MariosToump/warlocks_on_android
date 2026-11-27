class_name SimRunner
extends Node
## Sim sandbox (todo 13): drives a real game.tscn with forced spell loadouts,
## no title / countdown / shop / gold, every wizard a neutral bot. Logs one
## record per round. Never shipped (tools/* is excluded from the APK).
## See docs/superpowers/specs/2026-11-27-spell-sim-sandbox-design.md.

signal finished

const GAME := preload("res://scenes/game.tscn")
const TIMEOUT := 180.0 ## game seconds before a round is called a draw
## Fixed slots -> spell names for the cast counts (D / F use the spell id).
const SLOT_NAMES := {"Q": "fireball", "W": "blink", "E": "lightning", "R": "shield", "A": "staff"}

var mode := "ffa" ## "ffa" (4 wizards) | "duel" (2)
var rounds := 10
var pool: Array = Shop.SPELLS.keys()
var out_path := ""
var scenario_file := "" ## mode "scenario": a JSON setup (Task 4)
var records: Array[Dictionary] = []
var game: Node

var _options: Array = []
var _loadout := {} ## Wizard -> Array of spell ids this round
var _casts := {} ## Wizard -> {name: n}
var _kills := {} ## Wizard -> kills this round
var _lava := {} ## Wizard -> died in lava this round
var _fight_at := -1.0
var _armed := false
var _file: FileAccess
var _cfg := {} ## mode "scenario": the parsed JSON


## Every loadout from `ids`: none, each single, each pair (a < b).
static func loadouts(ids: Array) -> Array:
	var sorted := ids.duplicate()
	sorted.sort()
	var out: Array = [[]]
	for a in sorted:
		out.append([a])
	for i in sorted.size():
		for j in range(i + 1, sorted.size()):
			out.append([sorted[i], sorted[j]])
	return out


func _ready() -> void:
	_options = loadouts(pool)
	if out_path != "":
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		_file = FileAccess.open(out_path, FileAccess.WRITE)
	game = GAME.instantiate()
	game.title_screen = false
	game.apply_settings = false
	game.feel_effects = false
	game.countdown_time = 0.05
	game.round_over_time = 0.05
	game.gold_per_round = 0
	game.gold_per_kill = 0
	game.gold_for_win = 0
	if mode == "scenario":
		var path := scenario_file if scenario_file.begins_with("res://") else "res://" + scenario_file
		_cfg = JSON.parse_string(FileAccess.get_file_as_string(path))
		game.props_per_round = Vector2i.ZERO # a clean stage
	var player: Wizard = game.get_node("Wizards/Player")
	var pc := player.get_node_or_null("PlayerController")
	if pc:
		pc.free()
	_add_ai(player)
	add_child(game)
	for w: Wizard in game.all_wizards.duplicate():
		var keep: int = 2 if mode == "duel" else _cfg.wizards.size() if mode == "scenario" else 4
		if game.all_wizards.find(w) >= keep:
			_drop(w)
			continue
		var ai := w.get_node("AIController") as AIController
		ai.personality = _neutral()
		w.cast_started.connect(func(slot: String): _count_cast(w, slot))
		w.died.connect(func(_w): _on_died(w))
	game.round_started.connect(_on_round_started)
	game.fight_started.connect(func():
		_fight_at = GameClock.now()
		if mode == "scenario":
			_scenario_cast())
	game.round_ended.connect(_on_round_ended)
	game.kill_scored.connect(func(k: Wizard, _v): _kills[k] = _kills.get(k, 0) + 1)
	_armed = true
	game.start_match()


func _neutral() -> AIPersonality:
	var p := AIPersonality.new()
	p.personality_name = "Sim"
	return p


func _add_ai(w: Wizard) -> void:
	var ai := AIController.new()
	ai.name = "AIController"
	ai.profile = game.PROFILES[game.Difficulty.NORMAL]
	ai.personality = _neutral()
	w.add_child(ai)


func _drop(w: Wizard) -> void:
	game.all_wizards.erase(w)
	for d in [game.wins, game.kills, game.gold, game.round_kills]:
		d.erase(w)
	w.get_parent().remove_child(w)
	w.queue_free()


func _process(_delta: float) -> void:
	if _armed and mode == "scenario" and game.state == game.State.FIGHT and _fight_at >= 0.0:
		var someone_died: bool = game.alive_wizards().size() < game.all_wizards.size()
		if GameClock.now() - _fight_at > float(_cfg.get("secs", 5.0)) 				or (_cfg.get("until", "secs") == "death" and someone_died):
			game._end_round(null)
		return
	if _armed and game.state == game.State.FIGHT and _fight_at >= 0.0 \
			and GameClock.now() - _fight_at > TIMEOUT:
		_fight_at = -1.0
		game._end_round(null)


func _on_round_started(_n: int) -> void:
	if not _armed:
		return
	_fight_at = -1.0
	for w: Wizard in game.all_wizards:
		game.wins[w] = 0 # the match never ends (the HUD draws a pip per win needed)
		w.match_wins = 0
		set_loadout(w, _options.pick_random() if mode != "scenario" else [])
		_casts[w] = {}
		_kills[w] = 0
		_lava[w] = false
	if mode == "scenario":
		_scenario_setup()


## Replace `w`'s bought spells (D / F) with `ids` (level 0, no gold).
func set_loadout(w: Wizard, ids: Array) -> void:
	for slot in Shop.SHOP_SLOTS:
		Shop._remove_spell(w, slot)
	for id in ids:
		var node := Node.new()
		node.set_script(Shop.SPELLS[id].script)
		node.name = Shop.free_slot(w, id)
		w.get_node("Spells").add_child(node)
	_loadout[w] = ids.duplicate()


# --- scenario mode -------------------------------------------------------------

## Where a scenario puts something: "pos": [dx, dy] from the centre, or
## "<prefix>edge" / "edge_inset": px inside the island's edge (negative = out
## over the lava), along +x.
func _spot(d: Dictionary, prefix: String) -> Vector2:
	var c: Vector2 = game.arena.get_center()
	if d.has(prefix + "edge") or d.has("edge_inset"):
		var inset: float = d.get(prefix + "edge", d.get("edge_inset", 0.0))
		var r: float = game.arena.platform_radius_tiles * game.arena.tile_size
		return c + Vector2(r - inset, 0)
	var p: Array = d.get("pos" if prefix == "" else prefix + "pos", [0, 0])
	return c + Vector2(p[0], p[1])


## Round start in a scenario: everyone to their spot with their spells; the
## ones with "ai": false stand still.
func _scenario_setup() -> void:
	for i in game.all_wizards.size():
		var w: Wizard = game.all_wizards[i]
		var d: Dictionary = _cfg.wizards[i]
		w.reset(_spot(d, ""))
		set_loadout(w, d.get("loadout", []))
		w.move_dir = Vector2.ZERO


## Fight start (after the game turns the controllers on): the "ai": false
## wizards stand still, then the scripted cast.
func _scenario_cast() -> void:
	for i in game.all_wizards.size():
		var w: Wizard = game.all_wizards[i]
		var ai := w.get_node_or_null("AIController") as AIController
		if ai and not _cfg.wizards[i].get("ai", true):
			ai.process_mode = Node.PROCESS_MODE_DISABLED
			w.move_dir = Vector2.ZERO
			w.move_target = null
	var c: Dictionary = _cfg.get("cast", {})
	if c.is_empty():
		return
	var w: Wizard = game.all_wizards[int(c.get("who", 0))]
	var what: String = c.get("spell", "Q")
	var slot := what if what.length() == 1 else w.slot_of(what)
	w.cast(slot, _spot(c, "at_"))


func _scenario_record() -> Dictionary:
	var c: Vector2 = game.arena.get_center()
	var rec := {"round": records.size() + 1, "mode": "scenario",
			"secs": snappedf(GameClock.now() - _fight_at, 0.01),
			"deaths": [], "lava_deaths": [], "in_lava": [], "positions": {}}
	for w: Wizard in game.all_wizards:
		if not w.alive:
			rec.deaths.append(String(w.name))
		if _lava.get(w, false):
			rec.lava_deaths.append(String(w.name))
		if w.alive and game.arena.is_lava_at(w.global_position):
			rec.in_lava.append(String(w.name))
		var p := w.global_position - c
		rec.positions[String(w.name)] = [snappedf(p.x, 1.0), snappedf(p.y, 1.0)]
	return rec


func _count_cast(w: Wizard, slot: String) -> void:
	var s := w.get_spell(slot)
	var key: String = SLOT_NAMES.get(slot, s.spell_id if s else slot)
	var c: Dictionary = _casts.get(w, {})
	c[key] = c.get(key, 0) + 1
	_casts[w] = c


func _on_died(w: Wizard) -> void:
	if game.state == game.State.FIGHT and w.arena.is_lava_at(w.global_position):
		_lava[w] = true


func _on_round_ended(winner: Wizard) -> void:
	if mode == "scenario":
		_log(_scenario_record())
		return
	var timeout: bool = _fight_at < 0.0 and winner == null and game.state == game.State.ROUND_OVER
	var rec := {
		"round": records.size() + 1,
		"mode": mode,
		"secs": snappedf(GameClock.now() - _fight_at, 0.01) if _fight_at >= 0.0 else TIMEOUT,
		"timeout": timeout,
		"wizards": [],
	}
	for w: Wizard in game.all_wizards:
		var ai := w.get_node_or_null("AIController") as AIController
		rec.wizards.append({
			"name": String(w.name),
			"loadout": _loadout.get(w, []),
			"won": w == winner,
			"kills": _kills.get(w, 0),
			"died": not w.alive,
			"lava_death": _lava.get(w, false),
			"mood": ai.mood.name if ai else "",
			"casts": _casts.get(w, {}),
		})
	_log(rec)


func _log(rec: Dictionary) -> void:
	records.append(rec)
	if _file:
		_file.store_line(JSON.stringify(rec))
		_file.flush()
	if records.size() >= rounds:
		_armed = false
		game.set_process(false)
		finished.emit()
