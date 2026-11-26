class_name RockWallSpell
extends Spell
## F (bought in the shop): raise a short wall of rocks across the aim
## direction, a little in front of you. Blocks spells and walkers until it
## crumbles. Wizards standing where a rock comes up get bumped aside.

@export var rocks := 3
@export var life_by_level: Array[float] = [4.0, 4.5, 5.0, 5.5]
@export var distance := 60.0 ## from the caster to the middle of the wall
@export var spacing := 21.0 ## between rocks


func _init() -> void:
	spell_name = "Rock Wall"
	icon = Prop._texture(Prop.Kind.WALL)
	cooldown_by_level = [10.0, 9.0, 8.0, 7.0]
	cast_time = 0.3
	release_time = 0.15


## Where the rocks would come up for an aim at `target`.
func rock_points(target: Vector2) -> Array[Vector2]:
	var from := caster.global_position
	var dir := (target - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var mid := from + dir * distance
	var side := dir.orthogonal()
	var out: Array[Vector2] = []
	for i in rocks:
		out.append(mid + side * (i - (rocks - 1) / 2.0) * spacing)
	return out


func release(target: Vector2) -> void:
	var parent := caster.get_parent()
	for p in rock_points(target):
		if caster.arena and caster.arena.is_lava_at(p):
			continue
		for n in caster.get_tree().get_nodes_in_group("wizards"):
			var w := n as Wizard
			var off := w.global_position - p
			if w.alive and off.length() < 18.0:
				w.apply_knockback((off.normalized() if off.length() > 1.0 else Vector2.UP) * 260.0)
		var rock := Prop.make(Prop.Kind.WALL, p, caster.arena)
		rock.life = life_by_level[level]
		parent.add_child(rock)
	Sfx.play_at("hit", caster.global_position, -6.0)
