class_name GameClock
extends RefCounted
## Game time in seconds, counted in physics frames. Gameplay timers (kill
## credit, retaliation, the blink -> staff combo) use this instead of the
## wall clock, so a headless sim running faster than real time sees the
## same windows as the game. In the game it matches the wall clock (physics
## frames keep ticking during hit stop, as the wall clock does).


static func now() -> float:
	return Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)
