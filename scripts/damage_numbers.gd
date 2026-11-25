class_name DamageNumbers
extends Control
## Floating damage numbers, drawn in screen space (crisp at any zoom) over
## the wizard that was hit. They rise and fade. Hits on you are red.
## Lava ticks don't make numbers.

const LIFE := 0.8
const RISE := 36.0 ## screen px over the lifetime
const HEAD := Vector2(0, -44) ## world offset from a wizard's feet to above its head

var game: Node
## {world: Vector2, text: String, color: Color, age: float}
var numbers: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func add(w: Wizard, amount: float) -> void:
	var col := Color(1, 0.35, 0.3) if w == game.player else Color(1, 0.95, 0.8)
	# Small sideways jitter so quick hits don't stack exactly.
	var at := w.global_position + HEAD + Vector2(randf_range(-8.0, 8.0), 0)
	numbers.append({"world": at, "text": str(roundi(amount)), "color": col, "age": 0.0})


func _process(delta: float) -> void:
	for n in numbers:
		n.age += delta
	numbers = numbers.filter(func(n): return n.age < LIFE)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var to_screen := get_viewport().get_canvas_transform()
	for n in numbers:
		var t: float = n.age / LIFE
		var p: Vector2 = to_screen * n.world + Vector2(0, -RISE * t)
		var col: Color = n.color
		col.a = 1.0 - t * t
		var outline := Color(0, 0, 0, col.a)
		draw_string_outline(font, p + Vector2(-30, 0), n.text, HORIZONTAL_ALIGNMENT_CENTER, 60, 28, 6, outline)
		draw_string(font, p + Vector2(-30, 0), n.text, HORIZONTAL_ALIGNMENT_CENTER, 60, 28, col)
