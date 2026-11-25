class_name GameSettings
extends RefCounted
## Player settings, kept in static vars and saved to user://settings.cfg.
## The game reads them when `game.apply_settings` is on (tests turn it off).

const ZOOMS := {"close": 2.0, "far": 1.35} ## follow_zoom per choice (3 / 2 screen px per art px on a phone)
const WINS := [3, 5, 7]

static var path := "user://settings.cfg"
static var zoom := "close"
static var difficulty := 1 ## game.Difficulty: 0 easy, 1 normal, 2 hard
static var wins_to_take_match := 5
static var haptics := true
static var sound := true
static var music := true
static var _loaded := false


static func ensure_loaded() -> void:
	if not _loaded:
		load_settings()


static func load_settings() -> void:
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	zoom = cf.get_value("game", "zoom", zoom)
	if not ZOOMS.has(zoom):
		zoom = "close"
	difficulty = clampi(cf.get_value("game", "difficulty", difficulty), 0, 2)
	wins_to_take_match = cf.get_value("game", "wins_to_take_match", wins_to_take_match)
	if not wins_to_take_match in WINS:
		wins_to_take_match = 5
	haptics = cf.get_value("game", "haptics", haptics)
	sound = cf.get_value("game", "sound", sound)
	music = cf.get_value("game", "music", music)


static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "zoom", zoom)
	cf.set_value("game", "difficulty", difficulty)
	cf.set_value("game", "wins_to_take_match", wins_to_take_match)
	cf.set_value("game", "haptics", haptics)
	cf.set_value("game", "sound", sound)
	cf.set_value("game", "music", music)
	cf.save(path)


static func zoom_value() -> float:
	return ZOOMS[zoom]


## Back to defaults (tests).
static func reset() -> void:
	zoom = "close"
	difficulty = 1
	wins_to_take_match = 5
	haptics = true
	sound = true
	music = true
	_loaded = true
