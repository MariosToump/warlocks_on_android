class_name GravityWell
extends Node2D
## The Gravity Well spell on the ground (v0.12): for `duration` s it pulls
## every enemy of its caster within `radius` toward its centre. The pull is
## strongest in the middle (x1) and weakest at the rim (x RIM), so a wizard
## at the edge can walk out (walk 165 px/s) but not one in the middle.
## Shields don't stop it. Child of the arena (drawn on the floor).

const FRAMES := preload("res://assets/sprites/effects/gravity_well_frames.tres")
const RIM := 0.4

var caster: Wizard
var radius := 160.0
var duration := 2.5
var strength := 220.0 ## px/s at the centre
var age := 0.0
var _sprite: AnimatedSprite2D


static func spawn(at: Vector2, by: Wizard, p_strength: float) -> GravityWell:
	var g := GravityWell.new()
	g.caster = by
	g.strength = p_strength
	by.arena.add_child(g)
	g.global_position = at
	return g


func _ready() -> void:
	add_to_group("wells")
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FRAMES
	_sprite.scale = Vector2(2, 2) # 64 px art -> 128 px across; the pull reaches a bit past the arms
	_sprite.play()
	add_child(_sprite)
	Sfx.play_at("well", global_position)


## Pull (a velocity, px/s) the well puts on `w` right now.
func pull_on(w: Wizard) -> Vector2:
	if w == caster or not w.alive:
		return Vector2.ZERO
	var off := global_position - w.global_position
	var d := off.length()
	if d > radius or d < 2.0:
		return Vector2.ZERO
	return off / d * strength * lerpf(1.0, RIM, d / radius)


func _physics_process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	_sprite.modulate.a = minf(minf(age / 0.2, (duration - age) / 0.3), 1.0)
	for node in get_tree().get_nodes_in_group("wizards"):
		var w := node as Wizard
		w.pull += pull_on(w)
