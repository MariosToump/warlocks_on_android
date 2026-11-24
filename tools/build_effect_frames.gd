extends SceneTree
## Bakes PixelLab VFX exports (sheet PNG + JSON) into SpriteFrames .tres.
## Usage: godot --headless -s tools/build_effect_frames.gd -- res://a.json[:loop] ...
## Writes <name>_frames.tres next to each JSON, one animation "default".
## Frames are centred; the JSON pivot is stored as metadata "pivot_px"
## (pixel offset of the pivot from the frame centre) for scenes to use.


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var loop: bool = arg.ends_with(":loop")
		var json_path: String = arg.trim_suffix(":loop")
		_bake(json_path, loop)
	quit()


func _bake(json_path: String, loop: bool) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("bad json " + json_path)
		return
	var sheet := load(json_path.get_basename() + ".png") as Texture2D
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", loop)
	var total_ms := 0.0
	var list: Array = data.frames
	for f in list:
		var r: Dictionary = f.frame
		var tex := AtlasTexture.new()
		tex.atlas = sheet
		tex.region = Rect2(r.x, r.y, r.w, r.h)
		frames.add_frame("default", tex)
		total_ms += float(f.get("duration", 83))
	frames.set_animation_speed("default", 1000.0 * list.size() / total_ms)
	var first: Dictionary = list[0]
	var size := Vector2(first.sourceSize.w, first.sourceSize.h)
	var pivot := Vector2(first.pivot.x, first.pivot.y) * size
	frames.set_meta("pivot_px", pivot - size / 2.0)
	var out := json_path.get_basename() + "_frames.tres"
	var err := ResourceSaver.save(frames, out)
	print("saved %s (%s): %d frames @ %.1f fps, loop=%s, pivot %s" % [out, error_string(err), list.size(), frames.get_animation_speed("default"), loop, frames.get_meta("pivot_px")])
