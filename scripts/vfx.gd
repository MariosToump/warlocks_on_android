class_name Vfx
extends RefCounted
## Small particle effects built in code (visual pass 1): spark bursts on hits,
## puffs when a spell is released, embers on death. Particles are untextured
## squares, so they stay pixel-crisp. CPUParticles2D only (no GPU particle
## shader compile hitch on Android). At most MAX_LIVE bursts at once.

const MAX_LIVE := 24
const GROUP := "vfx_burst"

## Spark colour per kind of hit.
const COLORS := {
	"fire": Color(1.0, 0.55, 0.15),
	"lightning": Color(0.65, 0.9, 1.0),
	"push": Color(0.85, 0.78, 0.65),
	"swap": Color(0.75, 0.45, 1.0),
	"meteor": Color(1.0, 0.4, 0.1),
	"lava": Color(1.0, 0.35, 0.05),
}
## Cast puff colour per spell id (the starting spells have no id: by slot).
const SPELL_COLORS := {
	"Q": Color(1.0, 0.55, 0.15), # fireball
	"W": Color(0.7, 0.85, 1.0), # blink
	"E": Color(0.65, 0.9, 1.0), # lightning
	"R": Color(1.0, 0.85, 0.4), # shield
	"A": Color(1.0, 0.6, 0.25), # staff
	"homing": Color(1.0, 0.5, 0.2),
	"rockwall": Color(0.7, 0.62, 0.52),
	"boomerang": Color(0.95, 0.8, 0.5),
	"meteor": Color(1.0, 0.4, 0.1),
	"well": Color(0.6, 0.4, 1.0),
	"swap": Color(0.75, 0.45, 1.0),
	"timestop": Color(0.55, 0.95, 1.0),
}

## Kind of the last hit() call (tests).
static var last_hit_kind := ""


static func live_count(tree: SceneTree) -> int:
	var n := 0
	for b in tree.get_nodes_in_group(GROUP):
		if not b.is_queued_for_deletion():
			n += 1
	return n


## One-shot burst of square particles at `pos` (parent space = world).
## `dir` zero = all around; otherwise a cone of `spread` degrees. Returns
## null when MAX_LIVE bursts are already alive.
static func burst(parent: Node, pos: Vector2, color: Color, amount := 12, speed := 80.0,
		dir := Vector2.ZERO, spread := 180.0, life := 0.35) -> CPUParticles2D:
	if parent == null or not parent.is_inside_tree() or live_count(parent.get_tree()) >= MAX_LIVE:
		return null
	var p := CPUParticles2D.new()
	p.add_to_group(GROUP)
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.direction = dir.normalized() if dir != Vector2.ZERO else Vector2.UP
	p.spread = spread
	p.gravity = Vector2(0, 160)
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.8
	p.damping_max = speed * 1.6
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1).lerp(color, 0.4))
	ramp.set_color(1, Color(color.r * 0.6, color.g * 0.4, color.b * 0.4, 0.0))
	ramp.add_point(0.35, color)
	p.color_ramp = ramp
	p.z_index = 3
	p.position = pos
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.emitting = true
	return p


## Sparks where a wizard was hit, flying on with the blow (`dir`).
static func hit(parent: Node, pos: Vector2, dir: Vector2, kind: String) -> void:
	last_hit_kind = kind
	var c: Color = COLORS.get(kind, COLORS["push"])
	var at := pos + Vector2(0, -14)
	match kind:
		"meteor":
			burst(parent, at, c, 22, 150.0, Vector2.ZERO, 180.0, 0.45)
		"lightning":
			burst(parent, at, c, 14, 140.0, dir, 70.0, 0.25)
		_:
			burst(parent, at, c, 12, 100.0, dir, 60.0, 0.35)


## A small puff at the staff when a spell is let go.
static func cast_puff(parent: Node, pos: Vector2, spell_id: String) -> void:
	var c: Color = SPELL_COLORS.get(spell_id, Color(1.0, 0.7, 0.4))
	var p := burst(parent, pos + Vector2(0, -26), c, 8, 40.0, Vector2.UP, 180.0, 0.3)
	if p:
		p.gravity = Vector2(0, -30)


## Embers rising from a wizard that just died.
static func death_embers(parent: Node, pos: Vector2) -> void:
	var p := burst(parent, pos + Vector2(0, -12), COLORS["lava"], 26, 60.0, Vector2.UP, 70.0, 1.1)
	if p:
		p.gravity = Vector2(0, -40)
		p.explosiveness = 0.6
