extends SceneTree
## Builds a SpriteFrames resource from a PixelLab character export.
## Usage (run from the project folder, after importing):
##   godot --headless -s tools/build_sprite_frames.gd -- res://assets/sprites/red_warlock
## Expects <dir>/rotations/<direction>.png and
## <dir>/animations/<anim>/<direction>/frame_NNN.png.
## Only east-side + north/south directions are used; the wizard mirrors
## west-facing ones with flip_h so idle and walk always match.

const DIRS := ["south", "south-east", "east", "north-east", "north"]
const FPS := {"walk": 12.0, "hurt": 12.0, "death": 9.0, "attack": 20.0}
## Animations whose frame 0 is just the standing pose (PixelLab's reference
## frame): dropped so the move starts at once.
const SKIP_FIRST := ["attack"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("pass the character folder, e.g. -- res://assets/sprites/red_warlock")
		quit(1)
		return
	var base: String = args[0].trim_suffix("/")
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	for d in DIRS:
		var tex := load("%s/rotations/%s.png" % [base, d]) as Texture2D
		if tex == null:
			push_error("missing rotation " + d)
			continue
		var anim: String = "idle_" + d
		frames.add_animation(anim)
		frames.set_animation_loop(anim, true)
		frames.add_frame(anim, tex)

	var anim_root := base + "/animations"
	for kind in DirAccess.get_directories_at(anim_root):
		for d in DIRS:
			var dir := "%s/%s/%s" % [anim_root, kind, d]
			if not DirAccess.dir_exists_absolute(dir):
				continue
			var files := Array(DirAccess.get_files_at(dir)).filter(func(f): return f.ends_with(".png"))
			files.sort()
			if kind in SKIP_FIRST:
				files = files.slice(1)
			if files.is_empty():
				continue
			var anim := "%s_%s" % [kind, d]
			frames.add_animation(anim)
			frames.set_animation_speed(anim, FPS.get(kind, 10.0))
			frames.set_animation_loop(anim, kind in ["walk", "idle"])
			for f in files:
				frames.add_frame(anim, load(dir + "/" + f))

	var out := "%s/%s_frames.tres" % [base, base.get_file()]
	var err := ResourceSaver.save(frames, out)
	print("saved %s (%s) with %d animations" % [out, error_string(err), frames.get_animation_names().size()])
	quit(0 if err == OK else 1)
