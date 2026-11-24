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
## never have to meet inside one cell. Changing vertices and calling
## `rebuild()` is how the platform will shrink in milestone 6.

enum Terrain { LAVA, STONE, CRACKED }

const LAVA_SHEET := "res://assets/tiles/lava_stone"
const CRACK_SHEET := "res://assets/tiles/stone_cracked"

@export var platform_radius_tiles := 38.0 ## ~2 screens across
@export var lava_margin_tiles := 16 ## lava ring beyond the platform
@export_range(0.0, 1.0) var crack_threshold := 0.45 ## higher = fewer cracked patches
@export var seed_value := 0 ## 0 = random every run

@onready var tiles: TileMapLayer = $Tiles
@onready var camera: ArenaCamera = $Camera

var tile_size := 32
var map_cells := 0 ## map is map_cells x map_cells
var vertices: Array[PackedByteArray] = [] ## [row][col], (map_cells + 1)^2

# Wang index (NW*8 + NE*4 + SW*2 + SE) -> atlas coords, per sheet.
var _lava_lookup := {}
var _crack_lookup := {}
var _lava_source := -1
var _crack_source := -1


func _ready() -> void:
	tiles.tile_set = _build_tileset()
	map_cells = int(ceil(platform_radius_tiles)) * 2 + lava_margin_tiles * 2
	_generate_vertices()
	rebuild()
	camera.setup_bounds(get_bounds(), get_center())


## World-space rectangle covered by the map.
func get_bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(map_cells, map_cells) * tile_size)


func get_center() -> Vector2:
	return get_bounds().get_center()


## True if the given world position is over lava (for burn damage later).
func is_lava_at(world_pos: Vector2) -> bool:
	# Sample the nearest vertex: a point is lava when it's closer to a lava
	# corner than to the stone edge drawn by the tile.
	var v := (world_pos / tile_size).round()
	var r := int(v.y)
	var c := int(v.x)
	if r < 0 or c < 0 or r > map_cells or c > map_cells:
		return true
	return vertices[r][c] == Terrain.LAVA


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
	var phase := rng.randf() * TAU
	vertices.clear()
	for r in map_cells + 1:
		var row := PackedByteArray()
		row.resize(map_cells + 1)
		for c in map_cells + 1:
			var d := Vector2(c, r) - center
			var wobble := 0.6 * sin(d.angle() * 5.0 + phase) + 0.4 * sin(d.angle() * 9.0 - phase)
			row[c] = Terrain.STONE if d.length() <= platform_radius_tiles + wobble else Terrain.LAVA
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
			var nw := vertices[r][c]
			var ne := vertices[r][c + 1]
			var sw := vertices[r + 1][c]
			var se := vertices[r + 1][c + 1]
			var has_lava := Terrain.LAVA in [nw, ne, sw, se]
			if has_lava:
				var idx := _wang(nw != Terrain.LAVA, ne != Terrain.LAVA, sw != Terrain.LAVA, se != Terrain.LAVA)
				tiles.set_cell(Vector2i(c, r), _lava_source, _lava_lookup[idx])
			else:
				var idx := _wang(nw == Terrain.CRACKED, ne == Terrain.CRACKED, sw == Terrain.CRACKED, se == Terrain.CRACKED)
				tiles.set_cell(Vector2i(c, r), _crack_source, _crack_lookup[idx])
