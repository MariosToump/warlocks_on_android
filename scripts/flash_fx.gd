class_name FlashFx
extends Node2D
## Short code-drawn effects (visual review 2026-11-27, Blink and Swap barely
## showed): a flash ring, a beam between two points, and fading after-images
## of a wizard along a path. Drawn with whole-pixel rects so they stay crisp.

enum Kind { RING, BEAM }

var kind := Kind.RING
var color := Color.WHITE
var radius := 18.0
var to := Vector2.ZERO ## beam end, local
var life := 0.2
var age := 0.0


## An expanding ring plus a bright core, fading over `p_life` seconds.
static func ring(parent: Node, pos: Vector2, col: Color, r := 18.0, p_life := 0.22) -> FlashFx:
	var f := FlashFx.new()
	f.kind = Kind.RING
	f.color = col
	f.radius = r
	f.life = p_life
	f.z_index = 3
	parent.add_child(f)
	f.global_position = pos
	return f


## A bright 2 px line from `a` to `b` that fades over `p_life` seconds.
static func beam(parent: Node, a: Vector2, b: Vector2, col: Color, p_life := 0.18) -> FlashFx:
	var f := FlashFx.new()
	f.kind = Kind.BEAM
	f.color = col
	f.life = p_life
	f.z_index = 3
	parent.add_child(f)
	f.global_position = a
	f.to = b - a
	return f


## `count` ghost copies of `w`'s current frame between `from` and `to`,
## tinted `col`, the ones nearer `from` fading first.
static func afterimages(parent: Node, w: Wizard, from: Vector2, to_pos: Vector2, col: Color, count := 4) -> void:
	var spr := w.sprite
	if spr == null or spr.sprite_frames == null:
		return
	var tex := spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
	for i in count:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = spr.centered
		s.offset = spr.offset
		s.flip_h = spr.flip_h
		s.position = spr.position
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var holder := Node2D.new()
		holder.add_child(s)
		holder.z_index = 1
		parent.add_child(holder)
		var k := (i + 1) / float(count + 1)
		holder.global_position = from.lerp(to_pos, k).round()
		s.modulate = Color(col.r, col.g, col.b, 0.25 + 0.4 * k)
		var tw := holder.create_tween()
		tw.tween_property(s, "modulate:a", 0.0, 0.12 + 0.2 * k)
		tw.tween_callback(holder.queue_free)


func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(age / life, 0.0, 1.0)
	var c := color
	c.a = 1.0 - t
	match kind:
		Kind.RING:
			var r := lerpf(radius * 0.35, radius, sqrt(t))
			var n := 24
			for i in n:
				var a := i * TAU / n
				var p := Vector2(cos(a) * r, sin(a) * r * 0.62).round()
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), c)
			if t < 0.4:
				var core := Color(1, 1, 1, 1.0 - t / 0.4)
				var cr := roundf(lerpf(6.0, 2.0, t / 0.4))
				draw_rect(Rect2(Vector2(-cr, -cr * 0.62).round(), Vector2(cr * 2, cr * 1.24).round()), core)
		Kind.BEAM:
			var steps := int(to.length() / 2.0)
			for i in steps + 1:
				var p := (to * (i / float(maxi(steps, 1)))).round()
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), c)
				if i % 3 == 0:
					draw_rect(Rect2(p - Vector2(0, 2), Vector2(1, 1)), Color(1, 1, 1, c.a))
