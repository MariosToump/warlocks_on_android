class_name EnemyArrows
extends Control
## For every living enemy that is off-screen: an arrow on the screen edge
## pointing at them, in their team colour. Closer enemies get bigger arrows;
## an arrow pulses while that enemy is casting.

const INSET := 28.0 ## arrow tip distance from the screen edge
const NEAR := 300.0 ## world px: full size at this distance or closer
const FAR := 1400.0 ## world px: smallest at this distance or further
const SIZE := 30.0

var game: Node


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


## [{wizard, tip (screen), dir (screen, unit), scale}] for off-screen enemies.
func arrows() -> Array:
	var out := []
	if game == null or not game.state in [game.State.FIGHT, game.State.FREE]:
		return out
	var player: Wizard = game.player
	var to_screen := get_viewport().get_canvas_transform()
	var screen := Rect2(Vector2.ZERO, size)
	var center := size / 2.0
	for w: Wizard in game.all_wizards:
		if w == player or not w.alive:
			continue
		var sp := to_screen * w.global_position
		if screen.grow(-4.0).has_point(sp):
			continue
		var dir := (sp - center).normalized()
		if dir == Vector2.ZERO:
			continue
		# Where the line from the centre toward them crosses the inset rect.
		var half := center - Vector2(INSET, INSET)
		var t := minf(half.x / maxf(absf(dir.x), 0.0001), half.y / maxf(absf(dir.y), 0.0001))
		var d := player.global_position.distance_to(w.global_position)
		var k := 1.0 - 0.4 * clampf((d - NEAR) / (FAR - NEAR), 0.0, 1.0)
		out.append({"wizard": w, "tip": center + dir * t, "dir": dir, "scale": k})
	return out


func _draw() -> void:
	for a in arrows():
		var w: Wizard = a.wizard
		var col: Color = RoundHud.TEAM_COLORS[w.team_color]
		if w.is_casting():
			col = col.lerp(Color.WHITE, 0.35 + 0.35 * sin(Time.get_ticks_msec() / 60.0))
		var s: float = SIZE * a.scale
		var tip: Vector2 = a.tip
		var dir: Vector2 = a.dir
		var back := tip - dir * s
		var side := dir.orthogonal() * s * 0.6
		var pts := PackedVector2Array([tip, back + side, back - side])
		draw_colored_polygon(pts, Color(0, 0, 0, 0.55 * col.a))
		var inner := PackedVector2Array([tip - dir * 3.0, back + side * 0.7 + dir * 2.0, back - side * 0.7 + dir * 2.0])
		draw_colored_polygon(inner, col)
