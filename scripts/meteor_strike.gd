class_name MeteorStrike
extends Node2D
## The Meteor spell on the ground (v0.12): a warning ring for `delay` s
## while the rock falls, then a blast that hurts and pushes everyone in
## `radius` outward from the centre and scorches a crater. A shield takes
## the blast. Child of the arena (drawn on the floor; the rock above all).

const ROCK := preload("res://assets/sprites/effects/meteor_rock_frames.tres")
const BLAST := preload("res://assets/sprites/effects/fireball_impact_frames.tres")
const FALL_FROM := Vector2(-150, -240) ## where the rock starts, from the target

var caster: Wizard
var radius := 75.0
var delay := 1.0
var damage := 14.0
var knockback := 650.0
## Seconds since it was called (bots react after their reaction delay).
var age := 0.0
var _rock: AnimatedSprite2D


static func spawn(at: Vector2, by: Wizard, p_damage: float, p_knockback: float) -> MeteorStrike:
	var m := MeteorStrike.new()
	m.caster = by
	m.damage = p_damage
	m.knockback = p_knockback
	by.arena.add_child(m)
	m.global_position = at
	return m


func _ready() -> void:
	add_to_group("meteors")
	_rock = AnimatedSprite2D.new()
	_rock.sprite_frames = ROCK
	_rock.z_index = 3
	_rock.position = FALL_FROM
	_rock.play()
	add_child(_rock)
	Sfx.play_at("meteor_fall", global_position)


func _physics_process(delta: float) -> void:
	age += delta
	var t := clampf(age / delay, 0.0, 1.0)
	_rock.position = FALL_FROM.lerp(Vector2(0, -8), t * t) # speeds up as it falls
	_rock.scale = Vector2.ONE * lerpf(0.7, 1.2, t)
	queue_redraw()
	if age >= delay:
		_blast()


## Would the blast catch `w` where it stands now? (bots and tests)
func catches(w: Wizard) -> bool:
	return w.alive and w.global_position.distance_to(global_position) <= radius


func _blast() -> void:
	set_physics_process(false)
	for node in get_tree().get_nodes_in_group("props"):
		var rock := node as Prop
		var off := rock.global_position - global_position
		if off.length() <= radius + rock.radius:
			rock.push(off.normalized() * knockback * 0.7, caster)
	for node in get_tree().get_nodes_in_group("wizards"):
		var w := node as Wizard
		if not catches(w):
			continue
		var off := w.global_position - global_position
		var dir := off.normalized() if off.length() > 1.0 else Vector2.from_angle(randf() * TAU)
		if w.is_shielded():
			w.bubble_flash()
			continue
		w.take_damage(damage, caster if is_instance_valid(caster) else null)
		w.apply_knockback(dir * knockback)
		w.flash_hit(dir, "meteor")
	var arena := get_parent() as Arena
	if arena and not arena.is_lava_at(global_position):
		Crater.spawn(arena, global_position)
	if arena and arena.camera:
		arena.camera.shake(6.0, 0.3)
	var fx: EffectOneShot = load(EffectOneShot.SCENE).instantiate()
	fx.sprite_frames = BLAST
	fx.scale = Vector2(2.4, 2.4)
	get_parent().add_child(fx)
	fx.global_position = global_position + Vector2(0, -10)
	Sfx.play_at("meteor_boom", global_position)
	queue_free()


## The warning ring: chunky pixel dashes that pulse faster as it lands.
func _draw() -> void:
	var t := clampf(age / delay, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(age * lerpf(10.0, 28.0, t))
	var col := Color("ff9a2a").lerp(Color("c22a14"), pulse)
	col.a = 0.55 + 0.4 * t
	draw_colored_polygon(_ellipse(maxf(radius * t, 2.0), 24), Color(0.76, 0.16, 0.08, 0.12 + 0.18 * t))
	var n := 28
	for i in n:
		if i % 2 == 1:
			continue
		var a := i * TAU / n + age * 0.6
		var p := Vector2(cos(a) * radius, sin(a) * radius * 0.62).round()
		draw_rect(Rect2(p - Vector2(2, 1), Vector2(4, 2)), Color("1b0404"))
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 1)), col)


func _ellipse(r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := i * TAU / n
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.62))
	return pts
