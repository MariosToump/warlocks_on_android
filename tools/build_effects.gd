extends SceneTree
## Draws the v0.12 spell effects pixel by pixel (no PixelLab): hard pixels,
## the palette of our PixelLab effects (fireball / blink puff / lightning),
## a dark 1 px outline. Writes, per effect, a preview sheet <name>.png and
## <name>_frames.tres (one animation "default", the sheet embedded, meta
## "pivot_px" = 0: frames are centred on the object).
##   godot --headless --path . -s tools/build_effects.gd
## Re-run after changing a drawing; the game loads the .tres files.

const OUT := "res://assets/sprites/effects/"

# Palette (sampled from fireball / blink_puff / lightning_hit).
const INK := Color("1b0404") ## fire outline
const INK_DARK := Color("120f19") ## smoke / magic outline
const RED_D := Color("7a1410")
const RED := Color("c22a14")
const ORANGE := Color("f05a1c")
const AMBER := Color("ff9a2a")
const GOLD := Color("ffd04a")
const CREAM := Color("fff3a8")
const WHITE := Color("ffffff")
const PLUM_D := Color("2e1a2e")
const PLUM := Color("7a3a52")
const ROSE := Color("a8566e")
const BLUE_D := Color("3a5ad0")
const BLUE := Color("7cc4ff")
const ICE := Color("d8f4ff")
# One accent per spell.
const VIOLET_D := Color("5b2a8c")
const VIOLET := Color("b05cff")
const LILAC := Color("e0b8ff")
const PINK_D := Color("9c1f5e")
const PINK := Color("ff5ca8")
const PINK_L := Color("ffc2df")

var _rng := RandomNumberGenerator.new()
## Pixels drawn after the outline pass (loose sparks: an outline round a
## single pixel reads as a cross). [Vector2, Color] pairs.
var _late: Array = []


func _init() -> void:
	_rng.seed = 7 # same art every run
	_bake("boomerang", Vector2i(24, 24), 8, 16.0, true, _boomerang)
	_bake("meteor_rock", Vector2i(32, 32), 6, 12.0, true, _meteor)
	_bake("gravity_well", Vector2i(64, 40), 12, 12.0, true, _well)
	_bake("swap_orb", Vector2i(20, 20), 6, 14.0, true, _swap_orb)
	_bake("swap_puff", Vector2i(48, 48), 10, 18.0, false, _swap_puff)
	_bake("time_stop", Vector2i(72, 44), 10, 8.0, true, _time_stop)
	quit()


## Draw `count` frames with `draw.call(img, i, count)`, outline them, save.
func _bake(name: String, size: Vector2i, count: int, fps: float, loop: bool, draw: Callable) -> void:
	var cols := mini(count, 4)
	var rows := ceili(count / float(cols))
	var sheet := Image.create(size.x * cols, size.y * rows, false, Image.FORMAT_RGBA8)
	for i in count:
		var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		_late.clear()
		draw.call(img, i, count)
		_outline(img, INK_DARK if name in ["gravity_well", "swap_orb", "swap_puff", "time_stop"] else INK)
		for l in _late:
			_pxv(img, l[0], l[1])
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, size), Vector2i(i % cols, i / cols) * size)
	sheet.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	var tex := ImageTexture.create_from_image(sheet)
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", loop)
	frames.set_animation_speed("default", fps)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(Vector2(i % cols, i / cols) * Vector2(size), Vector2(size))
		frames.add_frame("default", at)
	frames.set_meta("pivot_px", Vector2.ZERO)
	var err := ResourceSaver.save(frames, OUT + name + "_frames.tres")
	print("%s: %d frames %dx%d (%s)" % [name, count, size.x, size.y, error_string(err)])


# --- pixel helpers -------------------------------------------------------------

func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


func _pxv(img: Image, p: Vector2, c: Color) -> void:
	_px(img, roundi(p.x), roundi(p.y), c)


## A loose spark, drawn after the outline.
func _spark(p: Vector2, c: Color) -> void:
	_late.append([p, c])


## A line one pixel wide with no gaps (steps one pixel at a time).
func _line(img: Image, a: Vector2, b: Vector2, col: Color) -> void:
	var n := maxi(ceili(maxf(absf(b.x - a.x), absf(b.y - a.y))), 1)
	for k in n + 1:
		_pxv(img, a.lerp(b, k / float(n)), col)


## Filled ellipse.
func _oval(img: Image, c: Vector2, r: Vector2, col: Color) -> void:
	for y in range(floori(c.y - r.y), ceili(c.y + r.y) + 1):
		for x in range(floori(c.x - r.x), ceili(c.x + r.x) + 1):
			var d := Vector2((x - c.x) / r.x, (y - c.y) / r.y)
			if d.length_squared() <= 1.0:
				_px(img, x, y, col)


## Ellipse ring 1 px thick (plotted by angle, no gaps).
func _ring(img: Image, c: Vector2, r: Vector2, col: Color, from := 0.0, to := TAU) -> void:
	var steps := int(maxf(r.x, r.y) * 8.0)
	for i in steps + 1:
		var a := lerpf(from, to, i / float(steps))
		_pxv(img, c + Vector2(cos(a) * r.x, sin(a) * r.y), col)


## Dark outline around everything drawn (like the PixelLab sprites).
func _outline(img: Image, ink: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var solid := []
	for y in h:
		for x in w:
			solid.append(img.get_pixel(x, y).a > 0.5)
	for y in h:
		for x in w:
			if solid[y * w + x]:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + o.x
				var ny: int = y + o.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and solid[ny * w + nx]:
					img.set_pixel(x, y, ink)
					break


# --- the effects ---------------------------------------------------------------

## A molten-edged obsidian crescent spinning (45 degrees a frame).
func _boomerang(img: Image, i: int, n: int) -> void:
	var c := Vector2(11.5, 11.5)
	var a := i * TAU / n
	var cut := c + Vector2.from_angle(a) * 5.0
	# motion smear: a faint arc behind the blade
	for k in 6:
		var t := a - 0.5 - k * 0.12
		_pxv(img, c + Vector2.from_angle(t + PI) * 9.0, AMBER if k < 3 else RED)
	for y in 24:
		for x in 24:
			var p := Vector2(x, y)
			var d := p.distance_to(c)
			if d > 9.5 or p.distance_to(cut) < 7.0:
				continue
			var edge := d > 7.8
			var lit := (p - c).dot(Vector2(-1, -1).normalized()) > 2.0
			var col := PLUM_D
			if edge:
				col = GOLD if lit else ORANGE
			elif d > 6.5:
				col = RED if lit else RED_D
			elif lit:
				col = PLUM
			_px(img, x, y, col)
	# hot tips
	for s in [-1.0, 1.0]:
		var tip := c + Vector2.from_angle(a + PI + s * 1.15) * 8.6
		_pxv(img, tip, CREAM)


## A burning rock falling down-right, flames streaming up-left (flickering).
func _meteor(img: Image, i: int, _n: int) -> void:
	var c := Vector2(20, 20)
	var back := Vector2(-1, -1).normalized()
	# flames: layered tongues, hottest near the rock
	var layers := [[RED, 15.0, 6.0], [ORANGE, 12.0, 4.8], [AMBER, 9.0, 3.6], [GOLD, 6.0, 2.4], [CREAM, 3.5, 1.4]]
	for L in layers:
		var col: Color = L[0]
		var length: float = L[1] + _rng.randf_range(-1.5, 1.5)
		var width: float = L[2]
		for s in int(length * 2.0):
			var t := s / 2.0
			var wob := sin(t * 0.9 + i * 1.7) * 1.2
			var half := width * (1.0 - t / length)
			var mid := c + back * t + back.orthogonal() * wob
			for k in range(-ceili(half), ceili(half) + 1):
				if absf(k) <= half:
					_pxv(img, mid + back.orthogonal() * k, col)
	# loose embers
	for e in 3:
		_pxv(img, c + back * _rng.randf_range(12, 17) + back.orthogonal() * _rng.randf_range(-5, 5), GOLD)
	# the rock: lumpy dark stone with glowing cracks
	for y in 32:
		for x in 32:
			var p := Vector2(x, y)
			var d := p.distance_to(c)
			var lump := 6.0 + 0.9 * sin(atan2(y - c.y, x - c.x) * 3.0 + 1.0)
			if d <= lump:
				var lit := (p - c).dot(back) > 1.5
				_px(img, x, y, PLUM if lit else PLUM_D)
	for k in 5: # cracks
		var t := k / 4.0
		_pxv(img, c + Vector2(-3 + t * 6, -1 + sin(t * 5.0) * 2.0), AMBER if (k + i) % 3 else GOLD)
	_pxv(img, c + Vector2(1, 3), ORANGE)
	_pxv(img, c + Vector2(2, 2), AMBER)


## A violet vortex seen from the 3/4 view (flattened): three spiral arms
## of sparks turning inward around a dark eye.
func _well(img: Image, i: int, n: int) -> void:
	var c := Vector2(31.5, 19.5)
	var squash := 0.58
	_oval(img, c, Vector2(9, 9 * squash), INK_DARK)
	_ring(img, c, Vector2(10, 10 * squash), VIOLET)
	_ring(img, c, Vector2(11, 11 * squash), VIOLET_D)
	var spin := -i * TAU / n / 3.0 # arms are 3-fold symmetric: a full loop in n frames
	for arm in 3:
		for s in 40:
			var t := s / 40.0
			var r := lerpf(30.0, 10.5, t)
			var a := spin + arm * TAU / 3.0 + t * 4.2
			var p := c + Vector2(cos(a) * r, sin(a) * r * squash)
			var col := PLUM
			if t > 0.75:
				col = LILAC
			elif t > 0.45:
				col = VIOLET
			elif t > 0.2:
				col = ROSE
			if t < 0.45:
				# outer arm: loose sparks (no outline), with gaps
				if s % 4 != 3:
					_spark(p, col)
					_spark(p + Vector2(1, 0), col)
				continue
			_pxv(img, p, col)
			_pxv(img, p + Vector2(1, 0), col)
	# sparks sucked in
	for k in 6:
		var a := k * TAU / 6.0 + i * 0.4
		var r := fmod(26.0 - i * 2.2 + k * 3.0, 18.0) + 12.0
		_spark(c + Vector2(cos(a) * r, sin(a) * r * squash), LILAC if k % 2 else WHITE)


## Two small orbs (pink and gold) circling each other: "trade places".
func _swap_orb(img: Image, i: int, n: int) -> void:
	var c := Vector2(9.5, 9.5)
	var a := i * TAU / n
	for k in 2:
		var p := c + Vector2.from_angle(a + k * PI) * 4.0
		var trail := Vector2.from_angle(a + k * PI - 0.6) * 4.0
		_pxv(img, c + trail, PINK_D if k == 0 else RED)
		_oval(img, p, Vector2(3.2, 3.2), PINK if k == 0 else AMBER)
		_oval(img, p + Vector2(-0.8, -0.8), Vector2(1.4, 1.4), PINK_L if k == 0 else CREAM)
	_px(img, 9, 9, WHITE)
	_px(img, 10, 10, WHITE)


## The swap flash: a pink and gold burst that throws chunky sparks out in a
## ring, which shrink and fade.
func _swap_puff(img: Image, i: int, n: int) -> void:
	var c := Vector2(23.5, 23.5)
	var t := i / float(n - 1)
	var r := lerpf(5.0, 19.0, sqrt(t))
	if i == 0:
		_oval(img, c, Vector2(7, 6), PINK)
		_oval(img, c, Vector2(4, 3.5), PINK_L)
		_oval(img, c, Vector2(1.5, 1.5), WHITE)
	elif i == 1:
		_oval(img, c, Vector2(5, 4.5), PINK_D)
		_oval(img, c, Vector2(3, 2.5), PINK)
	var sparks := 10
	var size := 2 if t < 0.55 else 1
	for k in sparks:
		if i == 0:
			break # the first frame is just the flash
		if t > 0.7 and (k + i) % 3 == 0:
			continue # thinning out
		var a := k * TAU / sparks + t * 1.2
		var p := c + Vector2(cos(a) * r, sin(a) * r * 0.8)
		var col := PINK if k % 2 else GOLD
		var hi := PINK_L if k % 2 else CREAM
		if t > 0.7:
			col = PINK_D if k % 2 else ORANGE
		if size == 2:
			_oval(img, p, Vector2(1.2, 1.2), col)
			_pxv(img, p + Vector2(-0.5, -0.5), hi)
		else:
			_spark(p, col)


## A frozen clock face on the ground: an icy ring with 12 gold ticks and a
## hand that clicks forward every other frame; frost glints.
func _time_stop(img: Image, i: int, _n: int) -> void:
	var c := Vector2(35.5, 21.5)
	var R := Vector2(33, 19)
	_ring(img, c, R, BLUE)
	_ring(img, c, R - Vector2(1, 1), ICE)
	_ring(img, c, R - Vector2(3, 2), BLUE_D)
	for k in 12:
		var a := k * TAU / 12.0
		var dir := Vector2(cos(a), sin(a))
		for s in (3 if k % 3 == 0 else 2):
			_pxv(img, c + dir * (R - Vector2(4 + s, 3 + s * 0.6)), GOLD if k % 3 == 0 else AMBER)
	var hand := (i / 2) * TAU / 5.0 - PI / 2.0
	var tip := c + Vector2(cos(hand) * 18.0, sin(hand) * 11.0)
	_line(img, c, tip, GOLD)
	_line(img, c + Vector2(0, 1), tip + Vector2(0, 1), CREAM)
	_oval(img, c, Vector2(2, 1.5), GOLD)
	for k in 4: # frost glints that twinkle round the rim
		var a := k * TAU / 4.0 + 0.4 + (i % 5) * 0.25
		var p := c + Vector2(cos(a) * R.x, sin(a) * R.y)
		if (i + k) % 2 == 0:
			_spark(p, WHITE)
			_spark(p + Vector2(1, 0), ICE)
			_spark(p + Vector2(-1, 0), ICE)
			_spark(p + Vector2(0, 1), ICE)
			_spark(p + Vector2(0, -1), ICE)
