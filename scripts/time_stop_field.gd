class_name TimeStopField
extends Node2D
## The Time Stop spell on the ground. Rework 2026-11-28 (the user's design):
## it freezes WIZARDS, not spells. Every wizard but the caster standing inside
## `radius` can't walk or cast until the field ends (knockback still moves
## them, so a hit can knock them out). Hits taken inside push 20% harder, and
## a wizard hit inside keeps that bonus for Wizard.TIME_MARK s after it gets
## out (see Wizard._update_time_stop). Projectiles fly through as normal.
## Child of the arena.

const FRAMES := preload("res://assets/sprites/effects/time_stop_frames.tres")

var caster: Wizard
var radius := 120.0
var duration := 1.5
var age := 0.0
var _sprite: AnimatedSprite2D


static func spawn(at: Vector2, by: Wizard, p_duration: float, p_radius := 120.0) -> TimeStopField:
	var f := TimeStopField.new()
	f.caster = by
	f.duration = p_duration
	f.radius = p_radius
	by.arena.add_child(f)
	f.global_position = at
	return f


## Is `w` held by any running Time Stop (not its own)?
static func holds(w: Wizard) -> bool:
	for n in w.get_tree().get_nodes_in_group("time_stops"):
		var f := n as TimeStopField
		if f.caster != w and f.running() and f.global_position.distance_to(w.global_position) <= f.radius:
			return true
	return false


func running() -> bool:
	return age < duration and not is_queued_for_deletion()


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
