class_name EffectOneShot
extends AnimatedSprite2D
## Plays its SpriteFrames' first animation once, then frees itself.

const SCENE := "res://scenes/effect_one_shot.tscn"

## PixelLab part exports are anchored at the subject's feet, which in the
## wizard scene are 7 px below the wizard's position.
const FEET_Y := 7.0


func _ready() -> void:
	z_index = 2
	animation_finished.connect(queue_free)
	play(sprite_frames.get_animation_names()[0])


## Spawns `frames` under `parent` so that its anchor (stored as the
## "pivot_px" meta by tools/build_effect_frames.gd) lands on the feet of a
## wizard standing at `wizard_pos`.
static func spawn_at_feet(frames: SpriteFrames, parent: Node, wizard_pos: Vector2) -> EffectOneShot:
	var fx: EffectOneShot = load(SCENE).instantiate()
	fx.sprite_frames = frames
	fx.offset = -frames.get_meta("pivot_px", Vector2.ZERO)
	fx.position = wizard_pos + Vector2(0, FEET_Y)
	parent.add_child(fx)
	return fx
