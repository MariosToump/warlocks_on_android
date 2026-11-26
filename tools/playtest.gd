extends SceneTree
## Playtest harness: full matches in rounds mode, the player driven by a bot
## (neutral personality) that also shops. Runs as fast as the CPU allows:
##   godot --headless --fixed-fps 60 --path . -s tools/playtest.gd -- [matches] [easy|normal|hard]
## Per match: length, rounds, fight lengths, player dead-time, deaths by cause
## (lava / damage), round wins + kills per wizard, gold spent. Totals at the end.
## Times are game seconds. "Match" counts the shop at its full length (the
## worst case: nobody presses Ready); the harness itself skips through it.

var game: Node
var player: Wizard
var t := 0.0 ## game seconds since the match started
var matches := 3
var nominal_shop := 0.0

var _round_start := 0.0
var _fight_start := 0.0
var _player_died_at := -1.0
var _m := {} ## this match's numbers
var _all: Array[Dictionary] = []
var _done := false
## v0.10 moods: rounds played / won in each mood, and each bot's mood rolls.
var _mood_rounds := {}
var _mood_wins := {}
var _bot_moods := {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	matches = int(args[0]) if args.size() > 0 else 3
	var diff: String = args[1] if args.size() > 1 else "normal"
	seed(12345)
	game = load("res://scenes/game.tscn").instantiate()
	game.bot_difficulty = {"easy": 0, "normal": 1, "hard": 2}[diff]
	game.apply_settings = false
	game.title_screen = false
	game.rounds = true
	if "noshop" in args: # experiment: no gold, nobody buys anything
		game.gold_per_round = 0
		game.gold_per_kill = 0
		game.gold_for_win = 0
	nominal_shop = game.shop_time
	game.shop_time = 0.05
	game.feel_effects = false
	player = game.get_node("Wizards/Player")
	var pc := player.get_node_or_null("PlayerController")
	if pc:
		pc.free()
	var ai := AIController.new()
	ai.name = "AIController"
	ai.profile = game.PROFILES[game.bot_difficulty]
	ai.personality = AIPersonality.new()
	ai.personality.personality_name = "Player"
	player.add_child(ai)
	root.add_child(game)
	_hook.call_deferred()
	print("=== playtest: %d matches, %s bots, first to %d ===" % [matches, diff, game.wins_to_take_match])


func _hook() -> void:
	game.round_started.connect(_on_round_started)
	game.fight_started.connect(func(): _fight_start = t)
	game.round_ended.connect(_on_round_ended)
	game.match_ended.connect(_on_match_ended)
	game.kill_scored.connect(func(k: Wizard, _v): _m.kills[_name(k)] += 1)
	game.shop_opened.connect(_on_shop_opened)
	for w: Wizard in game.all_wizards:
		w.died.connect(_on_died)
	_new_match()
	process_frame.connect(_tick)


func _new_match() -> void:
	t = 0.0
	_m = {"rounds": 0, "fights": [], "player_dead": 0.0, "lava_deaths": 0, "hit_deaths": 0,
			"wins": {}, "kills": {}, "deaths": {}, "spent": {}, "winner": ""}
	for w: Wizard in game.all_wizards:
		for k in ["wins", "kills", "deaths", "spent"]:
			_m[k][_name(w)] = 0


func _tick() -> void:
	if _done:
		return
	t += 1.0 / 60.0
	if t > 3600.0:
		print("match stuck over an hour, giving up")
		_finish()


func _on_round_started(_n: int) -> void:
	_round_start = t
	_player_died_at = -1.0
	for w: Wizard in game.all_wizards:
		var m := _mood(w)
		_mood_rounds[m] = _mood_rounds.get(m, 0) + 1
		var who := _name(w)
		if not _bot_moods.has(who):
			_bot_moods[who] = {}
		_bot_moods[who][m] = _bot_moods[who].get(m, 0) + 1


func _mood(w: Wizard) -> String:
	var ai := w.get_node_or_null("AIController") as AIController
	return ai.mood.name if ai else "?"


func _on_died(w: Wizard) -> void:
	if game.state != game.State.FIGHT:
		return
	_m.deaths[_name(w)] += 1
	if w.on_lava or w.arena.is_lava_at(w.global_position):
		_m.lava_deaths += 1
	else:
		_m.hit_deaths += 1
	if w == player:
		_player_died_at = t


func _on_round_ended(winner: Wizard) -> void:
	_m.fights.append(t - _fight_start)
	_m.rounds += 1
	if _player_died_at >= 0.0:
		_m.player_dead += t - _player_died_at
	if winner:
		_m.wins[_name(winner)] += 1
		var m := _mood(winner)
		_mood_wins[m] = _mood_wins.get(m, 0) + 1
		var key := _name(winner) + ":" + m # per wizard too (mood odds differ per bot)
		_mood_wins[key] = _mood_wins.get(key, 0) + 1


func _on_shop_opened() -> void:
	var before := {}
	for w: Wizard in game.all_wizards:
		before[w] = game.gold[w] if w == player else -1
	Shop.bot_shop(game, player)
	_m.spent["Player"] += before[player] - game.gold[player]
	t += nominal_shop - game.shop_time # count the shop as if it ran its full time


func _on_match_ended(winner: Wizard) -> void:
	_m.winner = _name(winner)
	_m.length = t
	_print_match(_all.size() + 1, _m)
	_all.append(_m)
	if _all.size() >= matches:
		_finish()
		return
	_new_match()
	game.start_match.call_deferred()


func _print_match(i: int, m: Dictionary) -> void:
	var fights: Array = m.fights
	var total_deaths: int = m.lava_deaths + m.hit_deaths
	print("match %d: %s  %d rounds  winner %s  fights %s s  player dead %.0f s  deaths %d (lava %d%%)  wins %s  kills %s" % [
			i, _clock(m.length), m.rounds, m.winner, fights.map(func(f): return int(f)),
			m.player_dead, total_deaths, _pct(m.lava_deaths, total_deaths), m.wins, m.kills])


func _finish() -> void:
	_done = true
	if _all.is_empty():
		quit(1)
		return
	var n := float(_all.size())
	var length := 0.0
	var fights: Array = []
	var lava := 0
	var deaths := 0
	var dead := 0.0
	var rounds := 0
	var wins := {}
	var died := {}
	var killed := {}
	for m in _all:
		for k in m.deaths:
			died[k] = died.get(k, 0) + m.deaths[k]
			killed[k] = killed.get(k, 0) + m.kills[k]
		length += m.length
		fights.append_array(m.fights)
		lava += m.lava_deaths
		deaths += m.lava_deaths + m.hit_deaths
		dead += m.player_dead
		rounds += m.rounds
		for k in m.wins:
			wins[k] = wins.get(k, 0) + m.wins[k]
	var fsum := 0.0
	for f in fights:
		fsum += f
	print("--- totals over %d matches ---" % _all.size())
	print("match length avg %s (target 5-8 min)" % _clock(length / n))
	print("fight avg %.0f s, min %.0f, max %.0f (target 35-60)" % [fsum / fights.size(), fights.min(), fights.max()])
	print("rounds per match %.1f, player dead per round %.0f s" % [rounds / n, dead / rounds])
	print("deaths %d, in lava %d%% (target >= 50%%)" % [deaths, _pct(lava, deaths)])
	var wtotal := 0
	for k in wins:
		wtotal += wins[k]
	var share := {}
	for k in wins:
		share[k] = "%d%%" % _pct(wins[k], wtotal)
	print("deaths per wizard %s, kills %s" % [died, killed])
	print("round wins share %s (target: nobody > 40%%)" % share)
	var mood_rate := {}
	for m in _mood_rounds:
		mood_rate[m] = "%d%%" % _pct(_mood_wins.get(m, 0), _mood_rounds[m])
	print("win rate per mood %s (rounds per mood %s)" % [mood_rate, _mood_rounds])
	print("moods per wizard %s" % _bot_moods)
	for who in _bot_moods:
		var rates := []
		for m in _bot_moods[who]:
			rates.append("%s %d%% of %d" % [m, _pct(_mood_wins.get(who + ":" + m, 0), _bot_moods[who][m]), _bot_moods[who][m]])
		print("  %s win rate by mood: %s" % [who, ", ".join(rates)])
	quit()


func _name(w: Wizard) -> String:
	if w == player:
		return "Player"
	var ai := w.get_node_or_null("AIController") as AIController
	return ai.personality.personality_name if ai and ai.personality else String(w.name)


func _clock(s: float) -> String:
	return "%d:%02d" % [int(s) / 60, int(s) % 60]


func _pct(a: int, b: int) -> int:
	return roundi(100.0 * a / b) if b > 0 else 0
