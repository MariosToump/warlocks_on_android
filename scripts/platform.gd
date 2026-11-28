class_name Platform
extends RefCounted
## Touch (phone) or PC (keyboard + mouse), decided once for the whole game.
## PC unless running on a phone; `--touch` after `--` on the command line
## forces the touch layer on a desktop (testing). Tests set `forced`.

enum Mode { AUTO, TOUCH, PC }

static var forced := Mode.AUTO


static func touch() -> bool:
	if forced != Mode.AUTO:
		return forced == Mode.TOUCH
	return OS.has_feature("mobile") or "--touch" in OS.get_cmdline_user_args()


## On PC the mouse must not pretend to be a finger.
static func apply() -> void:
	Input.emulate_touch_from_mouse = touch()
