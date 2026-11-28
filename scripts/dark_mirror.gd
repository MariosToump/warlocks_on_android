class_name DarkMirror
extends Node2D
## The Dark Mirror spell around its wizard (2026-11-28, replaces Rock Wall):
## dark glass panes on a ring round the caster, facing the aim. A spell that
## flies into a pane goes straight back to whoever cast it, at the same speed
## (a pure reflect; it now belongs to the mirror's wizard). Lightning is sent
## back down its own line. The panes cover `arc` radians (1/3, 2/3 or the
## whole ring by level) and sway a little; what you see is what reflects.
## Child of the wizard. Nothing here changes the wizard's own hitbox.

const RADIUS := 30.0 ## ring radius (the shield bubble is 22)
const SWAY := 0.17 ## +-radians the panes rock back and forth
const SWAY_SPEED := 2.2
const HEIGHT := 14.0 ## drawn at hand height above the feet
const SQUASH := 0.62 ## seen from above, flat like the other rings
const GLASS_D := Color("120f19")
const GLASS := Color("5b2a8c")
const GLASS_L := Color("b05cff")
const GLINT := Color("e0b8ff")

var wizard: Wizard
var arc := TAU / 3.0
var facing := 0.0 ## radians, the middle of the arc (the aim at cast time)
var duration := 2.5
var age := 0.0
var _back: Node2D


static func raise(w: Wizard, aim: Vector2, p_arc: float, p_duration: float) -> DarkMirror:
	var old := of(w)
	if old:
		old.queue_free()
		old.remove_from_group("mirrors")
	var m := DarkMirror.new()
	m.wizard = w
	m.arc = p_arc
	m.duration = p_duration
	var dir := aim - w.global_position
	m.facing = dir.angle() if dir.length() > 1.0 else 0.0
	w.add_child(m)
	return m


## The running mirror on `w`, or null.
static func of(w: Wizard) -> DarkMirror:
	for c in w.get_children():
		if c is DarkMirror and not c.is_queued_for_deletion():
			return c
	return null


## Does `w`'s mirror cover the direction `out` (from the wizard outward)?
static func covers(w: Wizard, out: Vector2) -> bool:
	var m := of(w)
	return m != null and m.covers_dir(out)


func covers_dir(out: Vector2) -> bool:
	if age >= duration or not wizard.alive:
		return false
	if arc >= TAU - 0.01:
		return true
	return absf(angle_difference(current_facing(), out.angle())) <= arc * 0.5


func current_facing() -> float:
	return facing + sin(age * SWAY_SPEED) * SWAY


func _ready() -> void:
	add_to_group("mirrors")
	_back = Node2D.new()
	_back.show_behind_parent = true
	_back.draw.connect(_draw_panes.bind(_back, false))
	add_child(_back)
	z_index = 1


func _physics_process(delta: float) -> void:
	age += delta
	if age >= duration or not wizard.alive:
		queue_free()
		return
	queue_redraw()
	_back.queue_redraw()


func _draw() -> void:
	_draw_panes(self, true)


## Lights up when a spell bounces off it.
func flash() -> void:
	modulate = Color(2.2, 2.2, 2.2)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.2)


## Panes on the front half (in front of the wizard) or the back half.
func _draw_panes(ci: CanvasItem, front: bool) -> void:
	var fade := clampf(minf(age / 0.12, (duration - age) / 0.3), 0.0, 1.0)
	if duration - age < 0.5 and int(age * 20.0) % 2 == 0:
		fade *= 0.4 # flicker before it goes, like the shield
	var panes := maxi(roundi(arc / (TAU / 15.0)), 1) # 5 / 10 / 15 panes
	var step := arc / panes
	var start := current_facing() - arc * 0.5
	for i in panes:
		var a := start + (i + 0.5) * step
		if (sin(a) > 0.0) != front:
			continue
		var tilt := sin(age * 3.0 + i) * 0.25 # each pane turns a little on its own
		var p := Vector2(cos(a) * RADIUS, sin(a) * RADIUS * SQUASH - HEIGHT)
		var along := Vector2(-sin(a), cos(a) * SQUASH).normalized().rotated(tilt)
		var half := along * (step * RADIUS * 0.42)
		var up := Vector2(0, -7)
		var quad := PackedVector2Array([(p - half).round(), (p + half).round(),
			(p + half + up).round(), (p - half + up).round()])
		var col := GLASS
		col.a = 0.85 * fade
		ci.draw_colored_polygon(quad, col)
		var edge := GLASS_D
		edge.a = fade
		ci.draw_polyline(quad + PackedVector2Array([quad[0]]), edge, 1.0)
		var top := GLASS_L
		top.a = fade
		ci.draw_line(quad[3], quad[2], top, 1.0) # a lit top edge so it reads on the dark floor
		# a light streak that slides across the glass
		var s := fposmod(age * 1.5 + i * 0.37, 1.0)
		var g := (p - half).lerp(p + half, s).round()
		var gl := GLINT if s < 0.5 else GLASS_L
		gl.a = fade
		ci.draw_rect(Rect2(g + Vector2(0, -6), Vector2(1, 4)), gl)
