class_name PlayerController
extends Node
## Drives the parent Wizard from keyboard + mouse.
## CLICK: right-click (or hold) to walk to the mouse, like WC3.
## Right-click an enemy to auto-attack it with the staff (walks up and keeps
## swinging). A: one staff swing at the enemy nearest the mouse.
## WASD: walk with W/A/S/D. Note: W is also the Blink key and D a spell
## slot, so WASD mode needs its own spell keys before it is offered.

enum MoveMode { CLICK, WASD }

const SPELL_SLOTS := ["Q", "W", "E", "R", "D", "F"]
## How close the mouse must be to an enemy to pick it (world px).
const PICK_RADIUS := 22.0
## A without an enemy near the mouse: swing at one this close to you.
const A_ASSIST := 120.0

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
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and wizard.attack_target == null:
				_set_target(wizard.get_global_mouse_position(), false)


func _unhandled_input(event: InputEvent) -> void:
	if not wizard.alive:
		return
	if event.is_action_pressed("attack"):
		_attack_key()
		get_viewport().set_input_as_handled()
		return
	for slot in SPELL_SLOTS:
		if event.is_action_pressed("spell_" + slot.to_lower()):
			wizard.cast(slot, wizard.get_global_mouse_position())
			get_viewport().set_input_as_handled()
			return
	if move_mode != MoveMode.CLICK:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		var enemy := _enemy_near(wizard.get_global_mouse_position(), PICK_RADIUS)
		if enemy:
			wizard.attack(enemy)
		else:
			_set_target(wizard.get_global_mouse_position(), true)


func _attack_key() -> void:
	var mouse := wizard.get_global_mouse_position()
	var enemy := _enemy_near(mouse, PICK_RADIUS)
	if enemy == null:
		enemy = _enemy_near(wizard.global_position, A_ASSIST)
	if enemy:
		wizard.attack(enemy, true)
	else:
		wizard.attack(null)
		wizard.cast("A", mouse)


## Closest living enemy within `radius` of `p` (measured to its body, which
## is drawn a little above its feet).
func _enemy_near(p: Vector2, radius: float) -> Wizard:
	var best: Wizard = null
	var best_d := radius
	for n in get_tree().get_nodes_in_group("wizards"):
		var w := n as Wizard
		if w == wizard or not w.alive:
			continue
		var d := minf(p.distance_to(w.global_position + Vector2(0, -14)), p.distance_to(w.global_position))
		if d <= best_d:
			best = w
			best_d = d
	return best


func _set_target(p: Vector2, show_marker: bool) -> void:
	wizard.attack(null)
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
