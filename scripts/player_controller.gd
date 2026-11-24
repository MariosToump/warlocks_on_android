class_name PlayerController
extends Node
## Drives the parent Wizard from keyboard + mouse.
## CLICK: right-click (or hold) to walk to the mouse, like WC3.
## WASD: walk with W/A/S/D. Note: W is also the Blink key from milestone 4,
## so WASD mode will need different spell keys when spells arrive.

enum MoveMode { CLICK, WASD }

@export var move_mode := MoveMode.CLICK

@onready var wizard: Wizard = get_parent()

var _marker: ClickMarker


func _ready() -> void:
	_marker = ClickMarker.new()
	_marker.top_level = true
	_marker.z_index = 5
	wizard.add_child.call_deferred(_marker)


func _process(_delta: float) -> void:
	if not wizard.alive:
		return
	match move_mode:
		MoveMode.WASD:
			wizard.move_target = null
			wizard.move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		MoveMode.CLICK:
			# Holding right mouse keeps re-targeting, which feels nicer.
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				_set_target(wizard.get_global_mouse_position(), false)


func _unhandled_input(event: InputEvent) -> void:
	if move_mode != MoveMode.CLICK or not wizard.alive:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		_set_target(wizard.get_global_mouse_position(), true)


func _set_target(p: Vector2, show_marker: bool) -> void:
	wizard.move_dir = Vector2.ZERO
	wizard.move_target = p
	if show_marker:
		_marker.show_at(p)


## Small shrinking ring where you right-clicked.
class ClickMarker extends Node2D:
	var _t := 1.0

	func show_at(p: Vector2) -> void:
		global_position = p
		_t = 0.0
		queue_redraw()

	func _process(delta: float) -> void:
		if _t < 1.0:
			_t = minf(_t + delta * 2.5, 1.0)
			queue_redraw()

	func _draw() -> void:
		if _t >= 1.0:
			return
		var r := lerpf(10.0, 3.0, _t)
		draw_arc(Vector2.ZERO, r, 0, TAU, 16, Color(0.5, 1.0, 0.4, 1.0 - _t), 2.0)
