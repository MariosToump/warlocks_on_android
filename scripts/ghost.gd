class_name Ghost
extends Node2D
## The player after dying in a fight, until the round ends: a pale, see-through
## copy of their wizard that floats around (over lava too) with the same
## joystick. Nothing can hit it and bots don't see it (not in "wizards").
## Haunt (the attack button): a small shove to living wizards close by, with
## no damage and no kill credit, every HAUNT_COOLDOWN seconds.
## Tapping the minimap teleports it there.

const SPEED := 577.5 ## 3.5x a wizard's walk (165), to get back fast
const HAUNT_RADIUS := 60.0
const HAUNT_PUSH := 220.0
const HAUNT_COOLDOWN := 4.0
const TINT := Color(0.45, 0.65, 1.0, 0.75) ## added on top (glows pale blue)

var source: Wizard ## the dead player (its move_dir steers the ghost)
var haunt_left := 0.0
var _t := 0.0
var _facing := "south"
var _ring := 0.0 ## haunt ring animation, 1 -> 0

var sprite: AnimatedSprite2D


func setup(from: Wizard) -> void:
	source = from
	global_position = from.global_position
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = from.sprite.sprite_frames
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = glow
	sprite.offset = from.sprite.offset
	sprite.centered = from.sprite.centered
	sprite.self_modulate = TINT
	add_child(sprite)
	z_index = 5
	_play("idle")
	Sfx.play_at("ghost", global_position)


func _physics_process(delta: float) -> void:
	_t += delta
	haunt_left = maxf(haunt_left - delta, 0.0)
	_ring = maxf(_ring - delta * 3.0, 0.0)
	var dir := source.move_dir.limit_length(1.0) if source else Vector2.ZERO
	global_position += dir * SPEED * delta
	if source and source.arena:
		var b := source.arena.get_bounds().grow(-8.0)
		global_position = global_position.clamp(b.position, b.end)
	if dir.length() > 0.1:
		_facing = Wizard.dir_name(dir)
		_play("walk")
	else:
		_play("idle")
	sprite.position.y = -4.0 + sin(_t * 3.0) * 2.0 # gentle float
	queue_redraw()


## Jump to a world point (the tapped minimap spot), kept inside the arena.
func teleport(to: Vector2) -> void:
	global_position = to
	if source and source.arena:
		var b := source.arena.get_bounds().grow(-8.0)
		global_position = global_position.clamp(b.position, b.end)
	_ring = 1.0
	Sfx.play_at("blink", global_position, -6.0)


## Shove every living wizard within reach. False while cooling down.
func haunt() -> bool:
	if haunt_left > 0.0:
		return false
	haunt_left = HAUNT_COOLDOWN
	_ring = 1.0
	for n in get_tree().get_nodes_in_group("wizards"):
		var w := n as Wizard
		if not w.alive:
			continue
		var off := w.global_position - global_position
		if off.length() <= HAUNT_RADIUS:
			var dir := off.normalized() if off.length() > 1.0 else Vector2.RIGHT
			w.apply_knockback(dir * HAUNT_PUSH)
	Sfx.play_at("blink", global_position, -6.0)
	return true


func cooldown_ratio() -> float:
	return haunt_left / HAUNT_COOLDOWN


func _play(kind: String) -> void:
	var frames := sprite.sprite_frames
	if frames == null:
		return
	var dir: String = Wizard.MIRROR.get(_facing, _facing)
	sprite.flip_h = Wizard.MIRROR.has(_facing)
	var anim := "%s_%s" % [kind, dir]
	if not frames.has_animation(anim):
		anim = "idle_%s" % dir
	if not frames.has_animation(anim):
		return
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-30, -46 + sin(_t * 3.0) * 2.0), "GHOST", HORIZONTAL_ALIGNMENT_CENTER, 60, 10,
			Color(0.75, 0.9, 1.0, 0.8))
	if _ring > 0.0:
		draw_arc(Vector2.ZERO, HAUNT_RADIUS * (1.0 - _ring * 0.6), 0, TAU, 32,
				Color(0.7, 0.9, 1.0, _ring * 0.7), 2.0)
