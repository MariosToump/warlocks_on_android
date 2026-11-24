extends Node2D
## A short-lived jagged lightning line drawn at hand height. Re-jitters a
## few times while it fades. Drawn without antialiasing so it stays pixel-y.

const HAND_Y := -16.0
const LIFE := 0.22
const OUTER := Color(0.35, 0.6, 1.0)
const INNER := Color(0.92, 0.98, 1.0)

var from := Vector2.ZERO
var to := Vector2.ZERO

var _age := 0.0
var _jitter_t := 0.0
var _points := PackedVector2Array()


func _ready() -> void:
	z_index = 3
	top_level = true
	global_position = Vector2.ZERO
	_rebuild()


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	_jitter_t += delta
	if _jitter_t >= 0.05:
		_jitter_t = 0.0
		_rebuild()
	modulate.a = 1.0 - pow(_age / LIFE, 2.0)
	queue_redraw()


func _rebuild() -> void:
	var a := from + Vector2(0, HAND_Y)
	var b := to + Vector2(0, HAND_Y)
	var length := a.distance_to(b)
	var n := maxi(int(length / 12.0), 2)
	var side := (b - a).normalized().orthogonal()
	_points.clear()
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		if i > 0 and i < n:
			p += side * randf_range(-6.0, 6.0)
		_points.append(p.round())


func _draw() -> void:
	if _points.size() < 2:
		return
	draw_polyline(_points, OUTER, 4.0)
	draw_polyline(_points, INNER, 2.0)
	# Small fork from a random joint.
	var i := _points.size() >> 1
	var fork := _points[i] + ((_points[i] - _points[0]).normalized().rotated(0.7) * 14.0).round()
	draw_line(_points[i], fork, OUTER, 2.0)
