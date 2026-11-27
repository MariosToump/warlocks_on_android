class_name Prop
extends CharacterBody2D
## A rock on the island (v0.9). Blocks wizards and spells.
## - Boulder (movable): spells and the staff shove it; rolling fast into a
##   wizard it hurts and pushes them (credited to whoever shoved it), then
##   slows. It sinks when it rolls into lava.
## - Pillar (fixed): pure cover. Sinks when the rising lava reaches it.
## - Wall rock (from the Rock Wall spell): fixed, crumbles after `life` s.
## Art is drawn in code (pixel shading into a small texture), no assets.

enum Kind { BOULDER, PILLAR, WALL }

const LAYER := 8 ## physics layer 4: props
const ROLL_DAMAGE := 6.0
const ROLL_HURT_SPEED := 140.0 ## px/s a boulder must roll at to hurt
const PUSH_FACTOR := 0.7 ## boulders are heavier than wizards
const FRICTION := 2.2

var kind := Kind.BOULDER
var radius := 11.0
var arena: Arena
var last_pusher: Wizard
var life := -1.0 ## seconds left (wall rocks), < 0 = forever
var sinking := false

var _sprite: Sprite2D
var _flash := 0.0
static var _textures := {}
## Which of 3 painted looks this rock uses (walls vary, so a Rock Wall isn't
## three copies of one stone).
var variant := 0


static func make(k: Kind, at: Vector2, on: Arena) -> Prop:
	var p := Prop.new()
	p.kind = k
	p.arena = on
	p.global_position = at
	p.radius = {Kind.BOULDER: 13.0, Kind.PILLAR: 11.0, Kind.WALL: 10.0}[k]
	p.variant = randi() % 3 if k == Kind.WALL else 0
	return p


func _ready() -> void:
	add_to_group("props")
	collision_layer = LAYER
	collision_mask = 2 | LAYER # wizards and other rocks
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = _texture(kind, variant)
	_sprite.centered = false
	var size := _sprite.texture.get_size()
	_sprite.offset = Vector2(-size.x / 2.0, -size.y + radius * 0.6)
	add_child(_sprite)
	if kind == Kind.WALL:
		# Bursts up out of the ground.
		_sprite.scale = Vector2(1, 0.1)
		create_tween().tween_property(_sprite, "scale", Vector2.ONE, 0.15)
	reset_physics_interpolation()


func is_movable() -> bool:
	return kind == Kind.BOULDER and not sinking


## Hit by a spell or staff: boulders get shoved, everything flashes.
func push(impulse: Vector2, by: Wizard) -> void:
	_flash = 0.12
	if not is_movable():
		return
	velocity += impulse * PUSH_FACTOR
	last_pusher = by


func _physics_process(delta: float) -> void:
	if sinking:
		return
	_flash = maxf(_flash - delta, 0.0)
	_sprite.modulate = Color(1.6, 1.4, 1.2) if _flash > 0.0 else Color.WHITE
	if life >= 0.0:
		life -= delta
		if life <= 0.0:
			crumble()
			return
	if velocity.length() > 2.0:
		var hit := move_and_collide(velocity * delta)
		if hit:
			_on_bump(hit)
		velocity *= exp(-FRICTION * delta)
	else:
		velocity = Vector2.ZERO
	if arena and arena.is_lava_at(global_position):
		sink()


func _on_bump(hit: KinematicCollision2D) -> void:
	var other := hit.get_collider()
	var speed := velocity.length()
	if other is Wizard and (other as Wizard).alive and speed >= ROLL_HURT_SPEED:
		var w := other as Wizard
		var dir := velocity.normalized()
		w.take_damage(ROLL_DAMAGE, last_pusher if last_pusher != w else null)
		w.apply_knockback(dir * speed * 0.9)
		w.flash_hit(dir)
		Sfx.play_at("hit", global_position, -4.0)
		velocity *= 0.3
	else:
		velocity = velocity.bounce(hit.get_normal()) * 0.5


## Into the lava: stop blocking, glow and go under.
func sink() -> void:
	if sinking:
		return
	sinking = true
	collision_layer = 0
	collision_mask = 0
	remove_from_group("props")
	var t := create_tween().set_parallel()
	t.tween_property(_sprite, "modulate", Color(1.8, 0.7, 0.3, 0.0), 0.9)
	t.tween_property(_sprite, "position:y", 10.0, 0.9)
	t.chain().tween_callback(queue_free)


## Wall rocks at the end of their time: crumble away.
func crumble() -> void:
	sinking = true
	collision_layer = 0
	collision_mask = 0
	remove_from_group("props")
	var t := create_tween().set_parallel()
	t.tween_property(_sprite, "scale", Vector2(1.2, 0.0), 0.25)
	t.tween_property(_sprite, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(queue_free)


func _draw() -> void:
	# Soft shadow under the rock.
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * radius * 1.1, sin(a) * radius * 0.45 + radius * 0.3))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.3))


## Does the segment a-b pass through any blocking rock? (AI line of sight.)
static func blocks(tree: SceneTree, a: Vector2, b: Vector2, margin := 4.0) -> bool:
	for n in tree.get_nodes_in_group("props"):
		var p := n as Prop
		var ab := b - a
		var t := clampf((p.global_position - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if (a + ab * t).distance_to(p.global_position) < p.radius + margin:
			return true
	return false


## First rock the ray from `from` along `dir` hits within `max_t` (for
## lightning). Returns [prop, distance] or [].
static func first_on_ray(tree: SceneTree, from: Vector2, dir: Vector2, max_t: float, width: float) -> Array:
	var best: Prop = null
	var best_t := INF
	for n in tree.get_nodes_in_group("props"):
		var p := n as Prop
		var t := (p.global_position - from).dot(dir)
		if t < 0.0 or t > max_t + p.radius:
			continue
		if (p.global_position - (from + dir * t)).length() <= p.radius + width and t < best_t:
			best = p
			best_t = maxf(t - p.radius, 0.0)
	return [best, best_t] if best else []


# --- art ------------------------------------------------------------------------

static func _texture(k: Kind, v := 0) -> Texture2D:
	var key := k * 10 + v
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(_paint(k, v))
	return _textures[key]


## Pixel-shaded rock: a lumpy ellipse (boulder), a column (pillar) or a
## chunky faceted block (wall). Visual review 2026-11-27: flat shade steps
## (4 tones, lit from the top left), a rough edge and a dark 1 px outline,
## so they match the pixel-art wizards instead of looking airbrushed.
static func _paint(k: Kind, v := 0) -> Image:
	var w := 30 if k == Kind.BOULDER else (22 if k == Kind.PILLAR else 26 + v * 2)
	var h := 26 if k == Kind.BOULDER else (42 if k == Kind.PILLAR else 30 - v * 2)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + k + v * 31
	var base := Color(0.62, 0.52, 0.44) if k != Kind.WALL else Color(0.6, 0.44, 0.34)
	# A rough edge: the radius wobbles with the angle (8 bumps, smoothed).
	var bumps: Array[float] = []
	for b in 8:
		bumps.append(rng.randf_range(0.0, 0.16 if k != Kind.PILLAR else 0.08))
	var rough := func(fx: float, fy: float) -> float:
		var a := fposmod(atan2(fy, fx), TAU) / TAU * 8.0
		var i0 := int(a) % 8
		var f := a - floorf(a)
		return 1.0 - lerpf(bumps[i0], bumps[(i0 + 1) % 8], f * f * (3.0 - 2.0 * f))
	var inside := func(x: int, y: int) -> bool:
		var fx := (x + 0.5) / w * 2.0 - 1.0
		var fy := (y + 0.5) / h * 2.0 - 1.0
		var r: float = rough.call(fx, fy)
		if k == Kind.BOULDER:
			return fx * fx + fy * fy <= r * r
		if k == Kind.WALL:
			# A chunky block: a squircle with a lumpy rim.
			return pow(absf(fx), 3.0) + pow(absf(fy), 3.0) <= r * r * r
		# Column: rounded top and bottom, slightly narrower up top.
		var half := (0.85 + 0.15 * fy) * r
		var top := absf(fx) / half
		if fy < -0.75:
			return top * top + pow((fy + 0.75) / 0.25, 2) <= 1.0
		if fy > 0.8:
			return top * top + pow((fy - 0.8) / 0.2, 2) <= 1.0
		return top <= 1.0
	var tones := [0.5, 0.7, 0.9, 1.1] # flat shade steps, dark to lit
	for y in h:
		for x in w:
			if not inside.call(x, y):
				continue
			var edge: bool = not (inside.call(x - 1, y) and inside.call(x + 1, y) and inside.call(x, y - 1) and inside.call(x, y + 1))
			if edge:
				img.set_pixel(x, y, Color(0.1, 0.08, 0.08))
				continue
			var lx := float(x) / w - 0.35
			var ly := float(y) / h - 0.3
			var light := clampf(1.0 - sqrt(lx * lx + ly * ly) * 1.3 + rng.randf_range(-0.04, 0.04), 0.0, 0.999)
			var c: Color = base * tones[int(light * tones.size())]
			if k == Kind.PILLAR and y % 9 == 0:
				c = base * 0.5 # stacked basalt joints
			c.a = 1.0
			img.set_pixel(x, y, c)
	# Facets on the wall (a few dark diagonal splits), cracks on the rest.
	var cracks := 3 if k != Kind.WALL else 5
	for i in cracks:
		var x := rng.randi_range(4, w - 5)
		var y := rng.randi_range(4, h - 5)
		var dx := rng.randi_range(-1, 1) if k != Kind.WALL else (1 if i % 2 else -1)
		for st in (4 if k != Kind.WALL else 7):
			if inside.call(x, y) and inside.call(x + 1, y) and inside.call(x - 1, y):
				img.set_pixel(x, y, base * 0.4)
				if k == Kind.WALL and inside.call(x, y + 1):
					img.set_pixel(x, y + 1, base * 1.15) # lit lip under the split
			x += dx if k == Kind.WALL else rng.randi_range(-1, 1)
			y += 1
	return img
