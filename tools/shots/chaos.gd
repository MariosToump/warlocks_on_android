extends "res://tools/shots/shot_base.gd"
## Real rounds: 4 AI wizards with shop spells, the player too, ~14 s of fight.

func _init() -> void:
	setup(true, true)
	var pc: Node = game.get_node("Wizards/Player/PlayerController")
	pc.free()
	var ai := AIController.new()
	ai.name = "AIController"
	ai.profile = game.PROFILES[1]
	ai.personality = AIPersonality.new()
	game.get_node("Wizards/Player").add_child(ai)
	_run.call_deferred()


func _run() -> void:
	await frames(2)
	grab()
	var ids := ["homing", "meteor", "well", "boomerang", "swap", "timestop", "mirror", "meteor"]
	var i := 0
	for w in [player, blue, green, purple]:
		give(w, ids[i]); give(w, ids[i + 1]); i += 2
	var secs := 14.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("secs="):
			secs = float(a.get_slice("=", 1))
	await seconds(secs)
	quit()
