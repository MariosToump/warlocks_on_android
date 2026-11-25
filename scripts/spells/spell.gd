class_name Spell
extends Node
## Base class for a spell in one of a wizard's slots (child of the wizard's
## Spells node). Each spell has a cooldown and upgrade levels 0-3 (the shop
## buys levels in milestone 7). Stats that change per level are arrays
## indexed by `level`.

@export var spell_name := "Spell"
@export var icon: Texture2D
## Tint for the icon on buttons (spells that share art look different).
var icon_tint := Color.WHITE
@export var cooldown_by_level: Array[float] = [2.0, 2.0, 2.0, 2.0]
## Seconds the caster stands still while casting.
@export var cast_time := 0.3
## When in the cast the spell actually fires (seconds after starting).
@export var release_time := 0.15
@export_range(0, 3) var level := 0
## Wizard animation played while casting ("cast" -> cast_<dir>).
var anim := "cast"
## If true the animation is stretched to exactly cast_time (attacks), else
## it may run a little past it as follow-through.
var anim_fits_cast := false
## If true, walking after the spell has fired cuts the follow-through short.
var cancel_on_move := false

var cooldown_left := 0.0
var caster: Wizard


func _ready() -> void:
	caster = get_parent().get_parent() as Wizard


func _process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func cooldown() -> float:
	return cooldown_by_level[level]


func is_ready() -> bool:
	return cooldown_left <= 0.0


## 1 right after casting, 0 when ready (for the HUD).
func cooldown_ratio() -> float:
	return cooldown_left / cooldown() if cooldown() > 0.0 else 0.0


func start_cooldown() -> void:
	cooldown_left = cooldown() * caster.cooldown_multiplier


## Override: do the spell's effect toward `target` (world position).
func release(_target: Vector2) -> void:
	pass
