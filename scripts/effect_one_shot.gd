extends AnimatedSprite2D
## Plays its SpriteFrames' first animation once, then frees itself.


func _ready() -> void:
	z_index = 2
	animation_finished.connect(queue_free)
	play(sprite_frames.get_animation_names()[0])
