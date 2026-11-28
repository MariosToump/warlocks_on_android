class_name PlayerController
extends Node
## Drives the parent Wizard from keyboard + mouse.
## CLICK: right-click (or hold) to walk to the mouse, like WC3.
## Right-click an enemy to auto-attack it with the staff (walks up and keeps
## swinging). A: one staff swing at the enemy nearest the mouse.
## WASD: walk with W/A/S/D. Note: W is also the Blink key and D a spell
## slot, so WASD mode needs its own spell keys before it is offered.
## Ghost (dead in a fight, PC): hold right mouse to float toward the mouse,
## A haunts, left-click the minimap to teleport there.
## Smart cast (2026-11-28): hold a spell key to see its range and hitbox
## (CastIndicator), let go to cast at the mouse, right-click to cancel.
## Shield / Dark Mirror, and the "instant" Casting setting, cast on key down.

enum MoveMode { CLICK, WASD }

const SPELL_SLOTS := ["Q", "W", "E", "R", "D", "F"]
## How close the mouse must be to an enemy to pick it (world px).
const PICK_RADIUS := 22.0
## A without an enemy near the mouse: swing at one this close to you.
const A_ASSIST := 120.0

@export var move_mode := MoveMode.CLICK

@onready var wizard: Wizard = get_parent()

var _marker: ClickMarker
## The player's ghost while dead in a fight (game.gd sets it).
var ghost: Ghost
var minimap: Minimap
## PC bar: right-clicks over it don't walk the warlock (game.gd sets it).
var bar: PcBar
## The spell key being held for a smart cast ("" when not aiming).
var aiming_slot := ""
var _indicator: CastIndicator
## After a right-click cancel, holding right mouse doesn't walk until released.
var _rmb_block := false


func _ready() -> void:
	_marker = ClickMarker.new()
	_marker.top_level = true
	_marker.z_index = 5
	wizard.add_child.call_deferred(_marker)
	_indicator = CastIndicator.new()
	wizard.add_child.call_deferred(_indicator)


func _process(_delta: float) -> void:
	if not wizard.alive:
		_stop_aiming()
		if ghost != null:
			_steer_ghost()
		return
	_update_aim()
	if _rmb_block and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_rmb_block = false
	match move_mode:
		MoveMode.WASD:
			wizard.move_target = null
			wizard.move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		MoveMode.CLICK:
			# Holding right mouse keeps re-targeting, which feels nicer.
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not _rmb_block and wizard.attack_target == null and not _over_bar(get_viewport().get_mouse_position()):
				_set_target(wizard.get_global_mouse_position(), false)


func _unhandled_input(event: InputEvent) -> void:
	if not wizard.alive:
		if ghost != null:
			_ghost_input(event)
		return
	if event.is_action_pressed("attack"):
		_attack_key()
		get_viewport().set_input_as_handled()
		return
	for slot in SPELL_SLOTS:
		var action: String = "spell_" + slot.to_lower()
		if event.is_action_pressed(action):
			_spell_key_down(slot)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_released(action) and slot == aiming_slot:
			wizard.cast(slot, wizard.get_global_mouse_position())
			_stop_aiming()
			get_viewport().set_input_as_handled()
			return
	var mb := event as InputEventMouseButton
	if aiming_slot != "" and mb and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		_stop_aiming() # right-click cancels the cast, and doesn't walk
		_rmb_block = true
		get_viewport().set_input_as_handled()
		return
	if move_mode != MoveMode.CLICK:
		return
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT and not _over_bar(mb.position):
		var enemy := _enemy_near(wizard.get_global_mouse_position(), PICK_RADIUS)
		if enemy:
			wizard.attack(enemy)
		else:
			_set_target(wizard.get_global_mouse_position(), true)


func _spell_key_down(slot: String) -> void:
	var spell := wizard.get_spell(slot)
	if spell == null:
		return
	if GameSettings.cast_mode == "instant" or CastIndicator.instant(spell):
		_stop_aiming()
		wizard.cast(slot, wizard.get_global_mouse_position())
		return
	aiming_slot = slot # another key while aiming switches to that spell
	_update_aim()


## Keep the indicator on the mouse; drop the aim if the key went up unseen
## (paused, or the controls were off when it was released).
func _update_aim() -> void:
	if aiming_slot == "":
		return
	var spell := wizard.get_spell(aiming_slot)
	if spell == null or not Input.is_action_pressed("spell_" + aiming_slot.to_lower()):
		_stop_aiming()
		return
	_indicator.show_for(spell, wizard, wizard.get_global_mouse_position())


func _stop_aiming() -> void:
	aiming_slot = ""
	if _indicator:
		_indicator.hide_now()


func _notification(what: int) -> void:
	# Controls switched off (countdown, round over) or the game paused.
	if what == NOTIFICATION_DISABLED or what == NOTIFICATION_PAUSED:
		_stop_aiming()


## Ghost: float toward the mouse while right mouse is held, else stop.
func _steer_ghost() -> void:
	var dir := Vector2.ZERO
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var off := wizard.get_global_mouse_position() - ghost.global_position
		if off.length() > 8.0:
			dir = off.normalized()
	wizard.move_dir = dir


func _ghost_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		ghost.haunt()
		get_viewport().set_input_as_handled()
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and minimap != null:
		var spot: Variant = minimap.world_at(mb.position)
		if spot != null:
			ghost.teleport(spot)
			get_viewport().set_input_as_handled()


func _over_bar(screen_pos: Vector2) -> bool:
	return bar != null and bar.blocks_mouse(screen_pos)


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
