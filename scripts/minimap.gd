class_name Minimap
extends Control
## Round minimap: the lava field, the stone platform as it is now, a pulsing
## ring where the edge is heading while the lava is about to rise, a dot per
## living wizard (you: bigger, white outline) and small fireball dots.

const DIAMETER := 150.0

var game: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(DIAMETER, DIAMETER)
	size = custom_minimum_size


func _process(_delta: float) -> void:
	queue_redraw()


## Minimap pixels per world pixel (the full platform fills ~87% of the disc).
func world_scale() -> float:
	var arena: Arena = game.arena
	return (DIAMETER / 2.0 - 4.0) / (arena.platform_radius_tiles * arena.tile_size * 1.15)


## Minimap-local position of a world point.
func to_map(world: Vector2) -> Vector2:
	return size / 2.0 + (world - game.arena.get_center()) * world_scale()


## World point under a screen position, or null when it's outside the disc.
func world_at(screen: Vector2) -> Variant:
	if game == null or not visible:
		return null
	var local := screen - get_global_rect().position
	if local.distance_to(size / 2.0) > DIAMETER / 2.0:
		return null
	return game.arena.get_center() + (local - size / 2.0) / world_scale()


func _draw() -> void:
	if game == null:
		return
	var arena: Arena = game.arena
	var c := size / 2.0
	var r := DIAMETER / 2.0
	var k := world_scale()
	var ts := float(arena.tile_size)
	draw_circle(c, r, Color(0.35, 0.08, 0.03, 0.8), true, -1.0, true)
	draw_circle(c, arena.radius_tiles * ts * k, Color(0.42, 0.4, 0.4, 0.9), true, -1.0, true)
	if arena.warning_active() and arena.next_radius_tiles < arena.radius_tiles:
		var a := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
		draw_arc(c, maxf(arena.next_radius_tiles * ts * k, 1.0), 0, TAU, 48,
				Color(1, 0.5, 0.1, 0.5 + 0.5 * a), 1.5, true)
	for n in game.wizards.get_children():
		if n is Projectile:
			draw_circle(to_map(n.global_position), 1.5, Color(1, 0.7, 0.3))
	for w: Wizard in game.all_wizards:
		if not w.alive:
			continue
		var p := to_map(w.global_position)
		var col: Color = RoundHud.TEAM_COLORS[w.team_color]
		if w == game.player:
			draw_circle(p, 5.5, Color.WHITE, true, -1.0, true)
			draw_circle(p, 4.0, col, true, -1.0, true)
		else:
			draw_circle(p, 4.0, Color(0, 0, 0, 0.7), true, -1.0, true)
			draw_circle(p, 3.0, col, true, -1.0, true)
	draw_arc(c, r - 1.0, 0, TAU, 64, Color(1, 0.55, 0.2, 0.9), 2.0, true)
