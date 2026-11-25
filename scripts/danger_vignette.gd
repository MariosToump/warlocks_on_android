class_name DangerVignette
extends TextureRect
## Red glow round the screen edges: a strong pulse while you burn in lava,
## a faint glow when lava is right next to you or the edge is about to
## swallow where you stand.

const NEAR_LAVA := 40.0 ## world px

var game: Node
## 0 = hidden, ~0.35 = near lava, ~0.8-1 = burning (read by tests).
var level := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 0.15, 0.05, 0), Color(1, 0.15, 0.05, 0), Color(1, 0.2, 0.05, 0.6)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 0.5)
	tex.width = 128
	tex.height = 128
	texture = tex
	modulate.a = 0.0


func _process(delta: float) -> void:
	var want := _target_level()
	level = move_toward(level, want, delta * 3.0)
	modulate.a = level


func _target_level() -> float:
	if game == null:
		return 0.0
	var p: Wizard = game.player
	if not p.alive or not game.state in [game.State.FIGHT, game.State.FREE]:
		return 0.0
	if p.on_lava:
		return 0.8 + 0.2 * sin(Time.get_ticks_msec() / 110.0)
	var arena: Arena = game.arena
	var at := p.global_position
	if arena.is_lava_soon(at):
		return 0.35
	for i in 8:
		if arena.is_lava_at(at + Vector2.from_angle(i * TAU / 8.0) * NEAR_LAVA):
			return 0.35
	return 0.0
