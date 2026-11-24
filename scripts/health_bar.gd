class_name HealthBar
extends Node2D
## Small pixel health bar floating above a wizard. Placeholder until the
## PixelLab UI art arrives; it only listens to the wizard's signal.

@export var width := 24
@export var height := 3

var _ratio := 1.0


func _ready() -> void:
	var w := get_parent() as Wizard
	w.health_changed.connect(_on_health_changed)


func _on_health_changed(current: float, maximum: float) -> void:
	_ratio = clampf(current / maximum, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var x := -width / 2.0
	draw_rect(Rect2(x - 1, -1, width + 2, height + 2), Color(0.05, 0.03, 0.03))
	draw_rect(Rect2(x, 0, width, height), Color(0.3, 0.08, 0.06))
	var col := Color(0.35, 0.9, 0.3) if _ratio > 0.5 else (Color(0.95, 0.75, 0.2) if _ratio > 0.25 else Color(0.95, 0.25, 0.15))
	draw_rect(Rect2(x, 0, roundf(width * _ratio), height), col)
