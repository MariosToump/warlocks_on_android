class_name Sfx
extends RefCounted
## Sound effects and music (static, usable from anywhere). The sounds are
## synthesized by tools/build_audio.gd into assets/audio/.
##
## - Sfx.play("coin")             UI / non-positional
## - Sfx.play_at("hit", pos)      in the world: quieter when far from the camera
## - Sfx.loop("lava", true/false) a looping sound on or off
## - Sfx.music("music_fight")     switch the music track ("" = stop)
## Players live under a "Sfx" node added to the scene root on first use.
## Buses: SFX and Music (default_bus_layout.tres); muted from the settings.

const SOUNDS := {
	"fireball": preload("res://assets/audio/fireball.wav"),
	"homing": preload("res://assets/audio/homing.wav"),
	"boomerang": preload("res://assets/audio/boomerang.wav"),
	"meteor_fall": preload("res://assets/audio/meteor_fall.wav"),
	"meteor_boom": preload("res://assets/audio/meteor_boom.wav"),
	"well": preload("res://assets/audio/well.wav"),
	"swap": preload("res://assets/audio/swap.wav"),
	"timestop": preload("res://assets/audio/timestop.wav"),
	"hit": preload("res://assets/audio/hit.wav"),
	"lightning": preload("res://assets/audio/lightning.wav"),
	"shield": preload("res://assets/audio/shield.wav"),
	"blink": preload("res://assets/audio/blink.wav"),
	"staff": preload("res://assets/audio/staff.wav"),
	"hurt": preload("res://assets/audio/hurt.wav"),
	"death": preload("res://assets/audio/death.wav"),
	"lava": preload("res://assets/audio/lava.wav"),
	"beep": preload("res://assets/audio/beep.wav"),
	"fight": preload("res://assets/audio/fight.wav"),
	"win": preload("res://assets/audio/win.wav"),
	"lose": preload("res://assets/audio/lose.wav"),
	"coin": preload("res://assets/audio/coin.wav"),
	"click": preload("res://assets/audio/click.wav"),
	"reflect": preload("res://assets/audio/reflect.wav"),
	"kill": preload("res://assets/audio/kill.wav"),
	"lava_warn": preload("res://assets/audio/lava_warn.wav"),
	"heartbeat": preload("res://assets/audio/heartbeat.wav"),
	"match_win": preload("res://assets/audio/match_win.wav"),
	"match_lose": preload("res://assets/audio/match_lose.wav"),
	"denied": preload("res://assets/audio/denied.wav"),
	"rockwall": preload("res://assets/audio/rockwall.wav"),
	"boomerang_return": preload("res://assets/audio/boomerang_return.wav"),
	"ghost": preload("res://assets/audio/ghost.wav"),
	"homing_hum": preload("res://assets/audio/homing_hum.wav"),
	"music_fight": preload("res://assets/audio/music_fight.wav"),
	"music_title": preload("res://assets/audio/music_title.wav"),
}
const VOICES := 12 ## sounds that can overlap
const WORLD_RANGE := 900.0 ## world sounds fade out to nothing at this distance
const MAX_SAME := 3 ## at most this many copies of one sound at once (extras are skipped)
## Always heard: these never get skipped, and only steal from each other.
const PRIORITY := ["death", "kill", "reflect", "fight", "win", "lose", "match_win", "match_lose", "lava_warn"]
const NEAR_PLAYER := 90.0 ## a world sound this close to the camera centre is the player's own: priority

static var _root: Node
static var _voices: Array[AudioStreamPlayer] = []
static var _prio: Array[bool] = [] ## per voice: is it playing a priority sound
static var _loops := {} ## name -> AudioStreamPlayer
static var _music: AudioStreamPlayer
static var music_name := ""
## Sounds played so far (tests read this; headless has no audio output).
static var played: Array[String] = []


## Headless runs (tests, tools) have no audio out; playing there only leaks
## playbacks at exit, so sounds are just recorded in `played`.
static func _silent() -> bool:
	return DisplayServer.get_name() == "headless"


static func _ensure() -> bool:
	if _silent():
		return false
	if is_instance_valid(_root):
		return true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	_root = Node.new()
	_root.name = "Sfx"
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.tree_exiting.connect(_forget)
	tree.root.add_child.call_deferred(_root)
	_voices.clear()
	_prio.clear()
	_loops.clear()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		_root.add_child(p)
		_voices.append(p)
		_prio.append(false)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	_root.add_child(_music)
	return true


## The scene is going away (quit / tests): drop every reference.
static func _forget() -> void:
	# Stop first: a playing stream is held by the audio server past exit.
	for p in _voices + _loops.values() + [_music]:
		if p is AudioStreamPlayer and is_instance_valid(p):
			p.stop()
			p.stream = null
	_voices.clear()
	_loops.clear()
	_music = null
	_root = null
	music_name = ""


static func play(name: String, volume_db := 0.0, pitch_jitter := 0.06, priority := false) -> void:
	if not SOUNDS.has(name):
		return
	priority = priority or name in PRIORITY
	played.append(name)
	if not _ensure():
		return
	var i := pick_voice(name, priority)
	if i < 0:
		return
	var p := _voices[i]
	_prio[i] = priority
	p.stream = SOUNDS[name]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	if p.is_inside_tree():
		p.play()
	else:
		p.play.call_deferred()


## Which voice a new sound gets (-1 = skip it). A free voice first; a sound
## already playing MAX_SAME times is skipped unless it's priority; otherwise
## steal the voice closest to finishing, never a priority one for a normal
## sound. Audio review 2026-11-27: round-robin cut off deaths and your own casts.
static func pick_voice(name: String, priority: bool) -> int:
	var same := 0
	var free := -1
	for i in _voices.size():
		var p := _voices[i]
		if p.playing:
			if p.stream == SOUNDS[name]:
				same += 1
		elif free < 0:
			free = i
	if same >= MAX_SAME and not priority:
		return -1
	if free >= 0:
		return free
	var best := -1
	var best_done := -1.0
	for i in _voices.size():
		if _prio[i] and not priority:
			continue
		var p := _voices[i]
		var length := p.stream.get_length() if p.stream else 1.0
		var done := p.get_playback_position() / maxf(length, 0.01)
		if done > best_done:
			best_done = done
			best = i
	return best


## A sound at a world position: full volume near the camera, silent past
## WORLD_RANGE (so far-off fights don't drown out yours).
static func play_at(name: String, world_pos: Vector2, volume_db := 0.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var cam := tree.root.get_camera_2d() if tree and tree.root else null
	if cam:
		var d := cam.get_screen_center_position().distance_to(world_pos)
		if d >= WORLD_RANGE:
			return
		volume_db += linear_to_db(1.0 - d / WORLD_RANGE * 0.85)
		play(name, volume_db, 0.06, d < NEAR_PLAYER)
		return
	play(name, volume_db)


static func loop(name: String, on: bool, volume_db := -4.0) -> void:
	if _silent():
		if on:
			_loops[name] = true
		else:
			_loops.erase(name)
		return
	if not _ensure():
		return
	var p: AudioStreamPlayer = _loops.get(name)
	if on:
		if p == null:
			p = AudioStreamPlayer.new()
			p.bus = &"SFX"
			p.stream = SOUNDS[name]
			_root.add_child(p)
			_loops[name] = p
		p.volume_db = volume_db
		if not p.playing:
			if p.is_inside_tree():
				p.play()
			else:
				p.play.call_deferred()
	elif p and p.playing:
		p.stop()


static func is_looping(name: String) -> bool:
	if _silent():
		return _loops.has(name)
	var p: AudioStreamPlayer = _loops.get(name)
	return p != null and p.playing


static func music(name: String) -> void:
	if name == music_name:
		return
	music_name = name
	if not _ensure():
		return
	if name == "":
		_music.stop()
		return
	_music.stream = SOUNDS[name]
	if _music.is_inside_tree():
		_music.play()
	else:
		_music.play.call_deferred()


## The shop: the music goes muffled (a low-pass on the Music bus), so the
## break between rounds sounds different from the fight.
static func muffle_music(on: bool) -> void:
	var bus := AudioServer.get_bus_index(&"Music")
	if bus < 0:
		return
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectLowPassFilter:
			AudioServer.set_bus_effect_enabled(bus, i, on)
			return


static func is_music_muffled() -> bool:
	var bus := AudioServer.get_bus_index(&"Music")
	if bus < 0:
		return false
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectLowPassFilter:
			return AudioServer.is_bus_effect_enabled(bus, i)
	return false


## A looping sound that follows `node` through the world and stops with it
## (the homing orb's hum). Fades with distance like play_at.
static func attach_loop(node: Node2D, name: String, volume_db := 0.0) -> void:
	played.append(name)
	if _silent() or not SOUNDS.has(name):
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = SOUNDS[name]
	p.bus = &"SFX"
	p.volume_db = volume_db
	p.max_distance = WORLD_RANGE
	p.attenuation = 1.0
	p.autoplay = true
	node.add_child(p)


## Mute buses from the settings.
static func apply_settings() -> void:
	var sfx := AudioServer.get_bus_index(&"SFX")
	var mus := AudioServer.get_bus_index(&"Music")
	if sfx >= 0:
		AudioServer.set_bus_mute(sfx, not GameSettings.sound)
	if mus >= 0:
		AudioServer.set_bus_mute(mus, not GameSettings.music)
