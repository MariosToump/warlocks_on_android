class_name AIMemory
extends RefCounted
## What a bot has *seen* other wizards do (v0.10): when it last saw each one
## cast a spell, and when each one was last hit by somebody else. Only what a
## player watching the screen would know -- it never reads anyone's cooldown.
## Times come from `clock` (the bot's own game-time clock).

var _clock: Callable
var _me: Wizard
var _watched := {} ## instance id -> true
var _casts := {} ## instance id -> {slot: time seen}
var _hit_by_other := {} ## instance id -> time it was hit by someone not us


func _init(me: Wizard, clock: Callable) -> void:
	_me = me
	_clock = clock


## Start watching `w` (safe to call again for the same wizard).
func watch(w: Wizard) -> void:
	var id := w.get_instance_id()
	if w == _me or _watched.has(id):
		return
	_watched[id] = true
	w.cast_started.connect(_on_cast.bind(id))
	w.damaged.connect(_on_damaged.bind(id))


## Seconds since we saw `w` cast `slot` (INF = never, or forgotten).
func seen(w: Wizard, slot: String) -> float:
	if w == null or not is_instance_valid(w):
		return INF
	var c: Dictionary = _casts.get(w.get_instance_id(), {})
	return _clock.call() - c[slot] if c.has(slot) else INF


## Seconds since `w` was last hit by somebody other than us (INF = never).
func since_hit_by_other(w: Wizard) -> float:
	if w == null or not is_instance_valid(w):
		return INF
	var id := w.get_instance_id()
	return _clock.call() - _hit_by_other[id] if _hit_by_other.has(id) else INF


## Forget the last round (connections stay).
func clear() -> void:
	_casts.clear()
	_hit_by_other.clear()


## Drop wizards that no longer exist.
func prune() -> void:
	for d in [_watched, _casts, _hit_by_other]:
		for id in d.keys():
			if not is_instance_id_valid(id):
				d.erase(id)


## How many wizards we remember a cast for (tests).
func known() -> int:
	prune()
	return _casts.size()


func _on_cast(slot: String, id: int) -> void:
	if not _casts.has(id):
		_casts[id] = {}
	_casts[id][slot] = _clock.call()


func _on_damaged(_amount: float, source: Wizard, id: int) -> void:
	if source != _me:
		_hit_by_other[id] = _clock.call()
