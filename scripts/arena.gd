class_name Arena
extends Node2D
## Round stone platform in a lava field.
##
## The map is described on a *vertex* grid (tile corners). Each vertex is
## LAVA, STONE or CRACKED. Every cell then picks the PixelLab Wang tile whose
## four corners match:
##   - any lava corner  -> lava/stone sheet (non-lava corners count as stone)
##   - otherwise        -> stone/cracked sheet
## Cracked stone is only placed away from the lava edge, so the two sheets
## never have to meet inside one cell.
##
## Shrinking: while `shrinks` is on, every `shrink_delay` seconds the edge
## creeps in by `shrink_step_tiles` (a glowing line warns `shrink_warning` s
## ahead), down to `min_radius_tiles`. After `min_hold` s at the minimum
## either the platform regrows (`regrows`, endless mode) or sudden death
## starts: the edge keeps creeping in until no stone is left (rounds).

enum Terrain { LAVA, STONE, CRACKED }
enum Phase { WAIT, SHRINK, HOLD, FINAL }

const LAVA_SHEET := "res://assets/tiles/lava_stone"
const CRACK_SHEET := "res://assets/tiles/stone_cracked"

@export var platform_radius_tiles := 28.0 ## ~2 screens across
@export var lava_margin_tiles := 16 ## lava ring beyond the platform
@export_range(0.0, 1.0) var crack_threshold := 0.45 ## higher = fewer cracked patches
@export var seed_value := 0 ## 0 = random every run

@export_group("Shrinking")
@export var shrinks := false ## the game turns this on
@export var shrink_delay := 18.0 ## seconds between shrinks
@export var shrink_step_tiles := 6.0 ## how far the edge creeps in each time
@export var shrink_speed := 3.0 ## tiles per second while creeping
@export var shrink_warning := 4.0 ## seconds of warning line before a shrink
@export var min_radius_tiles := 10.0 ## 3 steps of 6 from 28
@export var min_hold := 12.0 ## seconds at the minimum before it regrows / sudden death
@export var regrows := true ## false = sudden death after the hold (the game turns this off for rounds)
@export var final_shrink_speed := 1.2 ## tiles per second during sudden death
@export_group("")

@onready var tiles: TileMapLayer = $Tiles
@onready var camera: ArenaCamera = $Camera

var tile_size := 32
var map_cells := 0 ## map is map_cells x map_cells
var vertices: Array[PackedByteArray] = [] ## [row][col], (map_cells + 1)^2
var radius_tiles := 0.0 ## current platform radius (before the edge wobble)
var next_radius_tiles := 0.0 ## where the edge is heading / heads next
var phase := Phase.WAIT
var time_left := 0.0 ## seconds until the phase changes

# Wang index (NW*8 + NE*4 + SW*2 + SE) -> atlas coords, per sheet.
var _lava_lookup := {}
var _crack_lookup := {}
var _lava_source := -1
var _crack_source := -1
var _full_vertices: Array[PackedByteArray] = []
var _phase_offset := 0.0 ## wobble phase of the edge
## Embers rising off the lava just outside the island (visual pass 1).
var embers: CPUParticles2D
## Heat shimmer over the lava (screen-reading shader); see set_heat_haze().
var heat_haze: ColorRect
var _embers_radius := -100.0 ## radius the ember spots were placed for
var _embers_at := Vector2.ZERO ## camera position they were placed for
var _embers_clock := 0.0
## Perf (2026-11-28): every stone vertex inside the reach, sorted by the
## radius at which it turns to lava (its distance minus the edge wobble),
## biggest first. A shrink walks this list from `_melt_next` instead of
## testing the whole grid every frame, so the cost is only the vertices
## that actually melt. Same rule as before: lava when dist > r + wobble.
var _melt_order := PackedInt32Array() ## row * (map_cells + 1) + col
var _melt_at := PackedFloat64Array() ## radius below which it is lava
var _melt_next := 0
## Cells repainted since the last regrow; regrow() repaints only these.
var _dirty_cells := {}


func _ready() -> void:
	tiles.tile_set = _build_tileset()
	map_cells = int(ceil(platform_radius_tiles)) * 2 + lava_margin_tiles * 2
	_generate_vertices()
	_full_vertices = vertices.duplicate(true)
	_build_melt_order()
	radius_tiles = platform_radius_tiles
	rebuild()
	camera.setup_bounds(get_bounds(), get_center())
	var line := EdgeLine.new()
	line.arena = self
	line.z_index = 1
	add_child(line)
	_make_heat_haze()
	_make_embers()
	restart_shrink_timer()


## World-space rectangle covered by the map.
func get_bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(map_cells, map_cells) * tile_size)


func get_center() -> Vector2:
	return get_bounds().get_center()


## True if the given world position is over lava.
func is_lava_at(world_pos: Vector2) -> bool:
	# Sample the nearest vertex: a point is lava when it's closer to a lava
	# corner than to the stone edge drawn by the tile.
	var v := (world_pos / tile_size).round()
	var r := int(v.y)
	var c := int(v.x)
	if r < 0 or c < 0 or r > map_cells or c > map_cells:
		return true
	return vertices[r][c] == Terrain.LAVA


## True if `world_pos` is stone now but in the ring that is about to turn to
## lava (warning line showing, or the edge creeping in).
func is_lava_soon(world_pos: Vector2) -> bool:
	if not warning_active() or is_lava_at(world_pos):
		return false
	return _tiles_from_center(world_pos) > _edge_at(world_pos, next_radius_tiles) - 0.5


## is_lava_at(p) or is_lava_soon(p) in one call (perf, 2026-11-28: the bots
## ask this hundreds of times per think). Same rules, inlined.
func is_unsafe(world_pos: Vector2) -> bool:
	var g := world_pos / tile_size
	var v := g.round()
	var r := int(v.y)
	var c := int(v.x)
	if r < 0 or c < 0 or r > map_cells or c > map_cells:
		return true
	if vertices[r][c] == Terrain.LAVA:
		return true
	if not shrinks or phase == Phase.HOLD:
		return false
	if phase == Phase.WAIT and (time_left > shrink_warning or radius_tiles <= min_radius_tiles + 0.01):
		return false
	var d := g - Vector2(map_cells, map_cells) / 2.0
	return d.length() > next_radius_tiles + _wobble(d.angle()) - 0.5


func warning_active() -> bool:
	if not shrinks:
		return false
	if phase == Phase.SHRINK or phase == Phase.FINAL:
		return true
	return phase == Phase.WAIT and time_left <= shrink_warning and radius_tiles > min_radius_tiles + 0.01


## A random stone point well inside the current platform, clear of the ring
## that is about to go.
func random_stone_point() -> Vector2:
	var safe_r := (minf(radius_tiles, next_radius_tiles) - 2.0) * 0.8
	for i in 64:
		var p := get_center() + Vector2.from_angle(randf() * TAU) * sqrt(randf()) * safe_r * tile_size
		if not is_lava_at(p) and not is_lava_soon(p):
			return p
	return get_center()


## One line for the HUD about what the lava does next ("" = nothing to say).
func status_text() -> String:
	if not shrinks:
		return ""
	match phase:
		Phase.SHRINK:
			return "The lava is rising!"
		Phase.HOLD:
			if regrows:
				return "Platform regrows in %d" % ceili(time_left)
			return "Sudden death in %d" % ceili(time_left)
		Phase.FINAL:
			return "Sudden death!"
	if radius_tiles <= min_radius_tiles + 0.01:
		return ""
	return "Lava rises in %d" % ceili(time_left)


## Start the countdown to the next shrink from the full delay.
func restart_shrink_timer() -> void:
	phase = Phase.WAIT
	time_left = shrink_delay
	next_radius_tiles = maxf(radius_tiles - shrink_step_tiles, min_radius_tiles)


## Back to the full platform (cracks and all).
func regrow() -> void:
	vertices = _full_vertices.duplicate(true)
	radius_tiles = platform_radius_tiles
	_melt_next = 0
	# Only the cells the shrink touched differ from the full map.
	for cell: Vector2i in _dirty_cells:
		_paint(cell.y, cell.x)
	_dirty_cells.clear()
	_update_ember_points()
	restart_shrink_timer()


func _process(delta: float) -> void:
	_embers_clock += delta
	if embers and _embers_clock >= 0.5:
		_embers_clock = 0.0
		if camera.global_position.distance_to(_embers_at) > 96.0:
			_update_ember_points()


func _physics_process(delta: float) -> void:
	if not shrinks or map_cells == 0:
		return
	match phase:
		Phase.WAIT:
			time_left -= delta
			if time_left <= 0.0:
				if radius_tiles <= min_radius_tiles + 0.01:
					_start_hold()
				else:
					phase = Phase.SHRINK
		Phase.SHRINK:
			var r := radius_tiles - shrink_speed * delta
			_set_radius(next_radius_tiles if r <= next_radius_tiles + 0.001 else r)
			if radius_tiles == next_radius_tiles:
				if radius_tiles <= min_radius_tiles + 0.01:
					_start_hold()
				else:
					restart_shrink_timer()
		Phase.HOLD:
			time_left -= delta
			if time_left <= 0.0:
				if regrows:
					regrow()
				else:
					phase = Phase.FINAL
					next_radius_tiles = maxf(radius_tiles - 2.0, 0.0)
		Phase.FINAL:
			# The warning line runs 2 tiles ahead of the creeping edge.
			_set_radius(maxf(radius_tiles - final_shrink_speed * delta, 0.0))
			next_radius_tiles = maxf(radius_tiles - 2.0, 0.0)


func _start_hold() -> void:
	phase = Phase.HOLD
	time_left = min_hold


## Turn every vertex outside radius `r` to lava and repaint only the cells
## around the vertices that changed.
func _set_radius(r: float) -> void:
	radius_tiles = r
	var stride := map_cells + 1
	var changed: Array[Vector2i] = []
	while _melt_next < _melt_order.size() and (r <= 0.0 or _melt_at[_melt_next] > r):
		var i := _melt_order[_melt_next]
		_melt_next += 1
		@warning_ignore("integer_division")
		var row := i / stride
		var col := i % stride
		if vertices[row][col] != Terrain.LAVA:
			vertices[row][col] = Terrain.LAVA
			changed.append(Vector2i(col, row))
	if absf(r - _embers_radius) >= 0.5 or r <= 0.0:
		_update_ember_points()
	if changed.is_empty():
		return
	# Cracks stay 2 vertices away from lava (the two tile sheets can't meet
	# in one cell), so nearby cracks turn to plain stone. A cell's tile only
	# depends on its 4 corners, so only cells next to a vertex that changed
	# get repainted.
	var cells := {}
	for v in changed:
		_mark_cells(cells, v.y, v.x)
		for dr in range(-2, 3):
			var row := v.y + dr
			if row < 0 or row > map_cells:
				continue
			var line := vertices[row]
			for dc in range(-2, 3):
				var col := v.x + dc
				if col >= 0 and col <= map_cells and line[col] == Terrain.CRACKED:
					line[col] = Terrain.STONE
					_mark_cells(cells, row, col)
			vertices[row] = line
	for cell: Vector2i in cells:
		_paint(cell.y, cell.x)
		_dirty_cells[cell] = true


## The (up to) 4 cells that share vertex (row, col).
func _mark_cells(cells: Dictionary, row: int, col: int) -> void:
	if row > 0:
		if col > 0:
			cells[Vector2i(col - 1, row - 1)] = true
		if col < map_cells:
			cells[Vector2i(col, row - 1)] = true
	if row < map_cells:
		if col > 0:
			cells[Vector2i(col - 1, row)] = true
		if col < map_cells:
			cells[Vector2i(col, row)] = true


## Sort the full map's stone vertices by the radius at which they melt.
func _build_melt_order() -> void:
	var center := Vector2(map_cells, map_cells) / 2.0
	var reach := int(ceil(platform_radius_tiles + 2.0))
	var lo := maxi(0, int(center.x) - reach)
	var hi := mini(map_cells, int(center.x) + reach)
	var items := []
	for row in range(lo, hi + 1):
		for col in range(lo, hi + 1):
			if _full_vertices[row][col] == Terrain.LAVA:
				continue
			var d := Vector2(col, row) - center
			items.append([d.length() - _wobble(d.angle()), row * (map_cells + 1) + col])
	items.sort_custom(func(a, b): return a[0] > b[0])
	_melt_order.resize(items.size())
	_melt_at.resize(items.size())
	for k in items.size():
		_melt_at[k] = items[k][0]
		_melt_order[k] = items[k][1]
	_melt_next = 0


func _make_heat_haze() -> void:
	heat_haze = ColorRect.new()
	heat_haze.name = "HeatHaze"
	heat_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heat_haze.position = get_bounds().position
	heat_haze.size = get_bounds().size
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/heat_haze.gdshader")
	heat_haze.material = mat
	add_child(heat_haze)


func set_heat_haze(on: bool) -> void:
	heat_haze.visible = on
	heat_haze.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _make_embers() -> void:
	embers = CPUParticles2D.new()
	embers.name = "Embers"
	embers.z_index = 1
	embers.amount = Feel.ARENA_EMBERS
	embers.lifetime = Feel.ARENA_EMBER_LIFE
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	embers.direction = Vector2.UP
	embers.spread = 25.0
	embers.gravity = Vector2(0, -18)
	embers.initial_velocity_min = 8.0
	embers.initial_velocity_max = 22.0
	embers.scale_amount_min = 2.0
	embers.scale_amount_max = 3.0
	# Bright yellow-white cores: plain orange vanishes against the lava.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 0.8, 0.0))
	ramp.set_color(1, Color(0.35, 0.08, 0.02, 0.0))
	ramp.add_point(0.12, Color(1.0, 0.97, 0.7, 1.0))
	ramp.add_point(0.6, Color(1.0, 0.75, 0.3, 0.9))
	ramp.add_point(0.85, Color(0.45, 0.12, 0.04, 0.8))
	embers.color_ramp = ramp
	add_child(embers)
	_update_ember_points()
	embers.emitting = true


## Up to 64 random lava spots 1.5-5 tiles outside the current edge, on
## screen when the camera shows some (the ring is too long for 40 embers to
## be seen otherwise), else all around the island.
func _update_ember_points() -> void:
	if embers == null:
		return
	_embers_radius = radius_tiles
	_embers_at = camera.global_position
	var pts := PackedVector2Array()
	var center := get_center()
	var half := get_viewport_rect().size / camera.zoom / 2.0
	for i in 160:
		if pts.size() >= 64:
			break
		var p := camera.global_position + Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y))
		var out := _tiles_from_center(p) - _edge_at(p, radius_tiles)
		if out >= 1.0 and out <= 5.0 and is_lava_at(p):
			pts.append(p)
	if pts.size() >= 8:
		embers.emission_points = pts
		return
	pts.clear()
	for i in 160:
		if pts.size() >= 64:
			break
		var ang := randf() * TAU
		var r := maxf(radius_tiles + _wobble(ang), 0.0) + randf_range(1.5, 5.0)
		var p := center + Vector2.from_angle(ang) * r * tile_size
		if is_lava_at(p):
			pts.append(p)
	if pts.is_empty():
		pts.append(center)
	embers.emission_points = pts


func _wobble(angle: float) -> float:
	return 0.6 * sin(angle * 5.0 + _phase_offset) + 0.4 * sin(angle * 9.0 - _phase_offset)


## Distance from the map centre, in tiles.
func _tiles_from_center(world_pos: Vector2) -> float:
	return (world_pos / tile_size).distance_to(Vector2(map_cells, map_cells) / 2.0)


## Edge radius (tiles) toward `world_pos` for a platform of radius `r`.
func _edge_at(world_pos: Vector2, r: float) -> float:
	var d := world_pos / tile_size - Vector2(map_cells, map_cells) / 2.0
	return r + _wobble(d.angle())


# --- tileset -----------------------------------------------------------------

func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	var lava_meta := _load_json(LAVA_SHEET + "_metadata.json")
	tile_size = int(lava_meta.tileset_data.tile_size.width)
	ts.tile_size = Vector2i(tile_size, tile_size)
	_lava_source = _add_sheet(ts, LAVA_SHEET, lava_meta, _lava_lookup)
	_crack_source = _add_sheet(ts, CRACK_SHEET, _load_json(CRACK_SHEET + "_metadata.json"), _crack_lookup)
	return ts


func _add_sheet(ts: TileSet, base: String, meta: Dictionary, lookup: Dictionary) -> int:
	var src := TileSetAtlasSource.new()
	src.texture = load(base + "_image.png")
	src.texture_region_size = Vector2i(tile_size, tile_size)
	var id := ts.add_source(src)
	for t in meta.tileset_data.tiles:
		var box: Dictionary = t.bounding_box
		var coords := Vector2i((Vector2(box.x, box.y) / tile_size).floor())
		var idx := _wang(t.corners.NW == "upper", t.corners.NE == "upper",
				t.corners.SW == "upper", t.corners.SE == "upper")
		if lookup.has(idx):
			continue
		if not src.has_tile(coords):
			src.create_tile(coords)
		lookup[idx] = coords
	if lookup.size() < 16:
		push_warning("%s: only %d of 16 Wang tiles found" % [base, lookup.size()])
	return id


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Arena: can't open %s" % path)
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Arena: bad JSON in %s" % path)
		return {}
	return data


static func _wang(nw: bool, ne: bool, sw: bool, se: bool) -> int:
	return int(nw) * 8 + int(ne) * 4 + int(sw) * 2 + int(se)


# --- map ---------------------------------------------------------------------

func _generate_vertices() -> void:
	var rng := RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var center := Vector2(map_cells, map_cells) / 2.0
	# Slightly wobbly circle so the edge doesn't look machine-drawn.
	_phase_offset = rng.randf() * TAU
	vertices.clear()
	for r in map_cells + 1:
		var row := PackedByteArray()
		row.resize(map_cells + 1)
		for c in map_cells + 1:
			var d := Vector2(c, r) - center
			row[c] = Terrain.STONE if d.length() <= platform_radius_tiles + _wobble(d.angle()) else Terrain.LAVA
		vertices.append(row)
	# Cracked stone in a few organic patches, at least 2 vertices in from lava.
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.09

	for r in range(2, map_cells - 1):
		for c in range(2, map_cells - 1):
			if noise.get_noise_2d(c, r) > crack_threshold and _far_from_lava(r, c, 2):
				vertices[r][c] = Terrain.CRACKED


func _far_from_lava(r: int, c: int, dist: int) -> bool:
	for dr in range(-dist, dist + 1):
		for dc in range(-dist, dist + 1):
			if vertices[r + dr][c + dc] == Terrain.LAVA:
				return false
	return true


## Re-pick every cell's tile from the vertex grid.
func rebuild() -> void:
	tiles.clear()
	for r in map_cells:
		for c in map_cells:
			_paint(r, c)


## Pick cell (row r, column c)'s tile from its four corner vertices.
func _paint(r: int, c: int) -> void:
	var nw := vertices[r][c]
	var ne := vertices[r][c + 1]
	var sw := vertices[r + 1][c]
	var se := vertices[r + 1][c + 1]
	if Terrain.LAVA in [nw, ne, sw, se]:
		var idx := _wang(nw != Terrain.LAVA, ne != Terrain.LAVA, sw != Terrain.LAVA, se != Terrain.LAVA)
		var alt := 0
		if idx == 0:
			# All lava: flip / turn each cell by a fixed hash of its spot, so
			# the far lava doesn't repeat one tile in a grid (visual review 2026-11-27).
			var hsh := (c * 73856093) ^ (r * 19349663)
			alt = [0, TileSetAtlasSource.TRANSFORM_FLIP_H, TileSetAtlasSource.TRANSFORM_FLIP_V,
					TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V][absi(hsh) % 4]
		tiles.set_cell(Vector2i(c, r), _lava_source, _lava_lookup[idx], alt)
	else:
		var idx := _wang(nw == Terrain.CRACKED, ne == Terrain.CRACKED, sw == Terrain.CRACKED, se == Terrain.CRACKED)
		tiles.set_cell(Vector2i(c, r), _crack_source, _crack_lookup[idx])


## Pulsing line where the edge will be after the coming shrink.
class EdgeLine extends Node2D:
	var arena: Arena

	func _process(_delta: float) -> void:
		visible = arena.warning_active()
		if visible:
			queue_redraw()

	func _draw() -> void:
		var pts := PackedVector2Array()
		var center := arena.get_center()
		for i in 97:
			var a := i * TAU / 96.0
			var r := (arena.next_radius_tiles + arena._wobble(a)) * arena.tile_size
			pts.append(center + Vector2.from_angle(a) * r)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
		draw_polyline(pts, Color(1.0, 0.35 + 0.3 * pulse, 0.1, 0.45 + 0.4 * pulse), 3.0)
