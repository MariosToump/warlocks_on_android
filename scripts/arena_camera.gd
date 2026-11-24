class_name ArenaCamera
extends Camera2D
## Arena camera.
## - If `target` is set, smoothly follows it (used from milestone 2 on).
## - Otherwise free camera: arrow keys or middle-mouse drag to pan.
## - Mouse wheel zooms. Home key re-centres on the arena.
## Limits are set by the arena so the view never leaves the lava field.

@export var target: Node2D
@export var pan_speed := 600.0
@export var min_zoom := 0.5
@export var max_zoom := 2.0
@export var zoom_step := 0.1
@export var start_zoom := 0.5

var _home := Vector2.ZERO
var _dragging := false


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	zoom = Vector2(start_zoom, start_zoom)


## Called by the arena: world-space bounds of the map and its centre.
func setup_bounds(bounds: Rect2, home: Vector2) -> void:
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)
	_home = home
	global_position = home
	reset_smoothing()


func _process(delta: float) -> void:
	if target:
		global_position = target.global_position
		return
	var dir := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	if dir != Vector2.ZERO:
		global_position += dir * pan_speed * delta / zoom.x
		_clamp_to_limits()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(zoom.x + zoom_step)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(zoom.x - zoom_step)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging and not target:
		global_position -= (event as InputEventMouseMotion).relative / zoom.x
		_clamp_to_limits()
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_HOME:
		global_position = _home


func _set_zoom(z: float) -> void:
	z = clampf(z, min_zoom, max_zoom)
	zoom = Vector2(z, z)
	_clamp_to_limits()


## Keep the camera's own position inside the area it can actually show,
## so panning past a limit doesn't build up "hidden" offset.
func _clamp_to_limits() -> void:
	var half := get_viewport_rect().size / zoom / 2.0
	var min_p := Vector2(limit_left, limit_top) + half
	var max_p := Vector2(limit_right, limit_bottom) - half
	global_position = Vector2(
		clampf(global_position.x, min_p.x, maxf(min_p.x, max_p.x)),
		clampf(global_position.y, min_p.y, maxf(min_p.y, max_p.y)))
