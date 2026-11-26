class_name Crater
extends Node2D
## A scorched crater where a fireball burst (v0.9). Walkers in it are slowed
## until it cools down after `LIFE` seconds. Drawn in code.

const LIFE := 6.0
const RADIUS := 22.0
const SLOW := 0.6 ## walking speed multiplier inside

var _left := LIFE
var _embers: Array[Vector2] = []


static func spawn(parent: Node, at: Vector2) -> Crater:
	var c := Crater.new()
	parent.add_child(c)
	c.global_position = at
	return c


func _ready() -> void:
	add_to_group("craters") # (a child of the arena: drawn on the floor, under wizards)
	for i in 7:
		_embers.append(Vector2.from_angle(randf() * TAU) * sqrt(randf()) * RADIUS * 0.8 * Vector2(1, 0.55))


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	queue_redraw()


func is_hot() -> bool:
	return _left > 0.0


## Walking speed multiplier at `pos` (1 = no crater there).
static func speed_at(tree: SceneTree, pos: Vector2) -> float:
	for n in tree.get_nodes_in_group("craters"):
		var c := n as Crater
		var off := (pos - c.global_position) / Vector2(1, 0.55)
		if off.length() <= RADIUS:
			return SLOW
	return 1.0


func _draw() -> void:
	var k := clampf(_left / LIFE, 0.0, 1.0)
	var fade := minf(k * 3.0, 1.0) # fades out over the last third
	_ellipse(RADIUS, Color(0.08, 0.05, 0.04, 0.55 * fade))
	_ellipse(RADIUS * 0.7, Color(0.16, 0.08, 0.05, 0.6 * fade))
	# Glowing embers that cool from orange to dark red.
	var hot := Color(1.0, 0.55, 0.15).lerp(Color(0.5, 0.1, 0.05), 1.0 - k)
	for i in _embers.size():
		var flicker := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 120.0 + i * 1.7)
		draw_rect(Rect2(_embers[i].round(), Vector2(2, 2)), Color(hot, flicker * fade * k * 1.2))


func _ellipse(r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.55).round())
	draw_colored_polygon(pts, col)
