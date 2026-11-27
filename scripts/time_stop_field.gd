class_name TimeStopField
extends Node2D
## The Time Stop spell on the ground (v0.12): every projectile inside
## `radius` stands still (and stops animating) until the field ends, then
## carries on as it was. Wizards aren't affected. Child of the arena.

const FRAMES := preload("res://assets/sprites/effects/time_stop_frames.tres")

var caster: Wizard
var radius := 120.0
var duration := 2.0
var age := 0.0
var _sprite: AnimatedSprite2D


static func spawn(at: Vector2, by: Wizard, p_duration: float) -> TimeStopField:
	var f := TimeStopField.new()
	f.caster = by
	f.duration = p_duration
	by.arena.add_child(f)
	f.global_position = at
	return f


## Is `pos` inside any running Time Stop?
static func freezes(tree: SceneTree, pos: Vector2) -> bool:
	for n in tree.get_nodes_in_group("time_stops"):
		var f := n as TimeStopField
		if f.age < f.duration and f.global_position.distance_to(pos) <= f.radius:
			return true
	return false


## Does the straight line a -> b cross a running Time Stop? (bots)
static func on_line(tree: SceneTree, a: Vector2, b: Vector2) -> bool:
	for n in tree.get_nodes_in_group("time_stops"):
		var f := n as TimeStopField
		var p := Geometry2D.get_closest_point_to_segment(f.global_position, a, b)
		if f.age < f.duration and p.distance_to(f.global_position) <= f.radius:
			return true
	return false


func _ready() -> void:
	add_to_group("time_stops")
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FRAMES
	_sprite.scale = Vector2.ONE * radius / 120.0 # the art is drawn at radius 120: 1.0 = no upscaling
	_sprite.play()
	add_child(_sprite)
	Sfx.play_at("timestop", global_position)


func _physics_process(delta: float) -> void:
	age += delta
	_sprite.modulate.a = clampf(minf(age / 0.15, (duration - age) / 0.25), 0.0, 1.0)
	if age >= duration:
		queue_free()
