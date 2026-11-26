class_name ArenaCamera
extends Camera2D
## Arena camera.
## - If `target` is set, smoothly follows it (used from milestone 2 on).
## - Otherwise free camera: arrow keys or middle-mouse drag to pan.
## - Mouse wheel zooms. Home key re-centres on the arena.
## Limits are set by the arena so the view never leaves the lava field.
##
## Crisp pixels: the game stretches to the window (canvas_items), so the
## zoom is always picked so one art pixel covers a whole number of screen
## pixels (2, 3, ...) whatever the window or phone size. A fractional
## size like 2.25 is what makes pixel art look uneven and soft.

@export var target: Node2D
@export var pan_speed := 600.0
@export var min_zoom := 0.5
@export var max_zoom := 3.0
@export var zoom_step := 0.1
@export var start_zoom := 0.5

var _home := Vector2.ZERO
var _dragging := false
## Wanted zoom (in base-resolution units); the real zoom is snapped from it.
var _design_zoom := 1.0
## Screen shake: strength in world px, fades out over its time.
var _shake := 0.0
var _shake_time := 0.0
var _shake_left := 0.0


func _ready() -> void:
	# Follow on physics ticks (also set in arena.tscn): with physics interpolation on, the camera is
	# then interpolated together with what it follows, so no jitter.
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	get_tree().root.size_changed.connect(_apply_zoom)
	set_design_zoom(start_zoom)


## Called by the arena: world-space bounds of the map and its centre.
func setup_bounds(bounds: Rect2, home: Vector2) -> void:
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)
	_home = home
	global_position = home
	reset_smoothing()


## Zoom as it would be at the base 1280x720 resolution; snapped to whole
## screen pixels per art pixel.
func set_design_zoom(z: float) -> void:
	_design_zoom = clampf(z, min_zoom, max_zoom)
	_apply_zoom()


func _apply_zoom() -> void:
	var s := screen_scale()
	var px := maxf(roundf(_design_zoom * s), 1.0) # screen px per art px
	zoom = Vector2(px, px) / s
	_clamp_to_limits()


## How many screen pixels one base-resolution pixel covers right now.
func screen_scale() -> float:
	var win := get_tree().root
	var base := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
	return minf(win.size.x / base.x, win.size.y / base.y)


## Shake the view by up to `strength` world px, fading over `time` s. A
## weaker shake never cuts a stronger one short.
func shake(strength: float, time: float) -> void:
	var now := _shake * (_shake_left / maxf(_shake_time, 0.001))
	if strength < now:
		return
	_shake = strength
	_shake_time = time
	_shake_left = time


func shaking() -> bool:
	return _shake_left > 0.0


func _process(delta: float) -> void:
	if _shake_left > 0.0:
		_shake_left = maxf(_shake_left - delta, 0.0)
		var k := _shake_left / _shake_time
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * k
	elif offset != Vector2.ZERO:
		offset = Vector2.ZERO


func _physics_process(delta: float) -> void:
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
		# Wheel steps one whole pixel size in or out.
		var step := 1.0 / screen_scale()
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_design_zoom(zoom.x + step)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_design_zoom(zoom.x - step)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging and not target:
		global_position -= (event as InputEventMouseMotion).relative / zoom.x
		_clamp_to_limits()
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_HOME:
		global_position = _home


## Keep the camera's own position inside the area it can actually show,
## so panning past a limit doesn't build up "hidden" offset.
func _clamp_to_limits() -> void:
	var half := get_viewport_rect().size / zoom / 2.0
	var min_p := Vector2(limit_left, limit_top) + half
	var max_p := Vector2(limit_right, limit_bottom) - half
	global_position = Vector2(
		clampf(global_position.x, min_p.x, maxf(min_p.x, max_p.x)),
		clampf(global_position.y, min_p.y, maxf(min_p.y, max_p.y)))
