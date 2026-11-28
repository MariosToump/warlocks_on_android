class_name PerfStress
extends Node
## Performance stress run (2026-11-28). Not part of a normal game: started
## from tools/perf_stress.gd on the PC, or on the phone by tapping the version
## label on the title screen 5 times.
## Endless fight (respawns; the lava shrinks every 7 s and regrows), the
## player is a bot too, every wizard holds two shop spells, the heat shimmer
## follows the settings. It runs one pass per entry in `passes` (wizard count)
## and records every frame's wall-clock time, split by lava phase, so a
## stutter "when the lava moves" shows as SHRINK vs WAIT. Results go to the
## log ("PERF" lines; adb logcat -s godot) and on screen at the end.

const SPELL_PAIRS := [["homing", "mirror"], ["boomerang", "timestop"], ["swap", "meteor"],
		["homing", "well"], ["boomerang", "meteor"], ["swap", "timestop"]]
const WARMUP := 3.0

var passes: Array[int] = [4, 8] ## wizards per pass
var seconds := 90.0 ## per pass
var haze := true
var quit_when_done := false ## PC tool: quit instead of showing the results

var game: Node
var _pass := -1
var _t := 0.0
var _last := 0
var _frames := PackedFloat32Array()
var _phase_of := PackedByteArray()
var _second := 0.0
var _second_frames := 0
var _lines: Array[String] = []
var _status: Label


## Replace the running scene with a stress run.
static func launch(tree: SceneTree, p_passes: Array[int], p_seconds: float, p_haze: bool,
		p_quit := false) -> PerfStress:
	var s := PerfStress.new()
	s.passes = p_passes
	s.seconds = p_seconds
	s.haze = p_haze
	s.quit_when_done = p_quit
	if tree.current_scene:
		tree.current_scene.queue_free()
	tree.root.add_child.call_deferred(s)
	return s


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.add_theme_constant_override("outline_size", 5)
	_status.position = Vector2(12, 8)
	layer.add_child(_status)
	_log("PERF device=%s %s cpu=%s gpu=%s screen=%s hz=%.0f haze=%s" % [OS.get_name(), OS.get_model_name(),
			OS.get_processor_name(), RenderingServer.get_video_adapter_name(),
			DisplayServer.screen_get_size(), DisplayServer.screen_get_refresh_rate(), haze])
	_next_pass()


func _next_pass() -> void:
	if game:
		game.queue_free()
		game = null
	_pass += 1
	if _pass >= passes.size():
		_finish()
		return
	seed(777 + _pass)
	game = load("res://scenes/game.tscn").instantiate()
	game.apply_settings = false
	game.title_screen = false
	game.rounds = false
	var arena: Arena = game.get_node("Arena")
	arena.shrink_delay = 7.0
	arena.shrink_warning = 3.0
	arena.min_hold = 4.0
	var player: Wizard = game.get_node("Wizards/Player")
	var pc := player.get_node_or_null("PlayerController")
	if pc:
		pc.free()
	var ai := AIController.new()
	ai.name = "AIController"
	ai.profile = game.PROFILES[1]
	ai.personality = AIPersonality.new()
	player.add_child(ai)
	add_child(game)
	game.arena.set_heat_haze(haze)
	var extra: int = passes[_pass] - 1 - game.BOTS.size()
	for i in maxi(extra, 0):
		var b: Array = game.BOTS[i % game.BOTS.size()]
		game._spawn_bot(b[0], b[1], Vector2.from_angle(i * 1.3) * 180.0)
	var n := 0
	for w: Wizard in game.all_wizards:
		game.gold[w] = 999
		for id in SPELL_PAIRS[n % SPELL_PAIRS.size()]:
			Shop.buy_spell(game, w, id)
		n += 1
	_frames.clear()
	_phase_of.clear()
	_t = -WARMUP
	_second = 0.0
	_second_frames = 0
	_last = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := (now - _last) / 1000.0
	_last = now
	if game == null:
		return
	_t += dt / 1000.0
	if _t < 0.0:
		_status.text = "Performance test %d/%d: starting..." % [_pass + 1, passes.size()]
		return
	_frames.append(dt)
	_phase_of.append(game.arena.phase)
	_second += dt / 1000.0
	_second_frames += 1
	if _second >= 1.0:
		var line := "PERF pass=%d t=%d fps=%d draws=%d nodes=%d mem=%.1fMB phase=%s" % [_pass + 1, int(_t),
				_second_frames, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
				Arena.Phase.keys()[game.arena.phase]]
		print(line)
		_status.text = "Performance test %d/%d (%d wizards): %d s left, %d FPS" % [_pass + 1, passes.size(),
				passes[_pass], int(seconds - _t), _second_frames]
		_second = 0.0
		_second_frames = 0
	if _t >= seconds:
		_summarize()
		_next_pass()


func _summarize() -> void:
	var label := "%d wizards" % passes[_pass]
	_log("PERF === pass %d: %s, %.0f s ===" % [_pass + 1, label, seconds])
	_log(_report("all", _frames))
	for ph in [Arena.Phase.WAIT, Arena.Phase.SHRINK]:
		var f := PackedFloat32Array()
		for i in _frames.size():
			if _phase_of[i] == ph:
				f.append(_frames[i])
		if f.size() > 30:
			_log(_report(Arena.Phase.keys()[ph].to_lower(), f))
	@warning_ignore("integer_division")
	var third := _frames.size() / 3
	_log(_report("first 1/3", _frames.slice(0, third)))
	_log(_report("last 1/3", _frames.slice(_frames.size() - third)))


## One summary line: average FPS, 1% low, frame-time percentiles, hitches.
static func _report(label: String, f: PackedFloat32Array) -> String:
	if f.is_empty():
		return "%s: no frames" % label
	var s := f.duplicate()
	s.sort()
	var total := 0.0
	for x in f:
		total += x
	var over := 0
	for x in f:
		if x > 33.3:
			over += 1
	var p99: float = s[int(s.size() * 0.99)]
	var mid := s.size() >> 1
	return "%-9s fps=%5.1f 1%%low=%5.1f p50=%5.1fms p95=%5.1f p99=%5.1f max=%6.1f hitches(>33ms)=%d of %d" % [
			label, f.size() / (total / 1000.0), 1000.0 / p99, s[mid], s[int(s.size() * 0.95)],
			p99, s[-1], over, f.size()]


func _log(line: String) -> void:
	print(line)
	_lines.append(line.trim_prefix("PERF "))


func _finish() -> void:
	if quit_when_done:
		get_tree().quit()
		return
	_status.text = "\n".join(_lines) + "\n\nTake a screenshot, then tap to go back."
	_status.add_theme_font_size_override("font_size", 15)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_status.get_parent().add_child(bg)
	_status.get_parent().move_child(bg, 0)
	bg.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed or e is InputEventScreenTouch and e.pressed:
			get_tree().change_scene_to_file("res://scenes/game.tscn")
			queue_free())
