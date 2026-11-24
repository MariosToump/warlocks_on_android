class_name AIController
extends Node
## Drives the parent Wizard as a bot (milestone 5), the way PlayerController
## drives the player: it only sets move_target and calls cast() / attack().
##
## Every think tick (profile.think_interval) it picks a target, scores every
## action for the current situation, multiplies each score by the
## personality's weight and runs the best one. Cast actions fire once;
## movement actions set a goal that is followed every physics frame.

## Every action has _score_<name>() -> float and _do_<name>() -> void.
const ACTIONS := ["reposition", "fireball"]
## Bonus for sticking with the current action / target (stops jitter).
const KEEP_ACTION_BONUS := 0.1
const KEEP_TARGET_BONUS := 80.0
## "Near lava" for targeting: lava within this distance.
const NEAR_LAVA := 110.0

@export var profile: AIProfile
@export var personality: AIPersonality
@export var debug_draw := false

@onready var wizard: Wizard = get_parent()

var target: Wizard = null
var current_action := ""

var _think_left := 0.0
var _now := 0.0
var _last_cast := -100.0
## Where movement actions want to walk (null = stand).
var _goal = null
## +1 / -1: which way the bot circles its target while repositioning.
var _strafe := 1.0
var _strafe_left := 0.0


func _ready() -> void:
	if profile == null:
		profile = AIProfile.new()
	if personality == null:
		personality = AIPersonality.new()
	_strafe = 1.0 if randf() < 0.5 else -1.0
	_think_left = randf() * profile.think_interval # bots don't think in lockstep


func _physics_process(delta: float) -> void:
	if not wizard.alive or wizard.arena == null:
		target = null
		_goal = null
		return
	_now += delta
	_strafe_left -= delta
	if _strafe_left <= 0.0:
		_strafe_left = randf_range(1.5, 3.5)
		_strafe = -_strafe
	_think_left -= delta
	if _think_left <= 0.0:
		_think_left = profile.think_interval * randf_range(0.8, 1.2)
		_think()
	_steer()


# --- deciding ---------------------------------------------------------------

func _think() -> void:
	target = _pick_target()
	var best := ""
	var best_score := -INF
	for action in ACTIONS:
		var s: float = call("_score_" + action) * personality.weight(action)
		if s <= 0.0:
			continue
		s += randf() * 0.05
		if action == current_action:
			s += KEEP_ACTION_BONUS
		if s > best_score:
			best_score = s
			best = action
	current_action = best
	if best != "":
		call("_do_" + best)


## Nearest living enemy, preferring hurt ones and ones standing near lava.
func _pick_target() -> Wizard:
	var best: Wizard = null
	var best_cost := INF
	for n in get_tree().get_nodes_in_group("wizards"):
		var w := n as Wizard
		if w == wizard or not w.alive:
			continue
		var cost := wizard.global_position.distance_to(w.global_position)
		cost -= (w.max_health - w.health) * 2.0
		if _lava_within(w.global_position, NEAR_LAVA):
			cost -= 150.0
		if w == target:
			cost -= KEEP_TARGET_BONUS
		if cost < best_cost:
			best_cost = cost
			best = w
	return best


func _can_cast(slot: String) -> bool:
	var spell := wizard.get_spell(slot)
	return spell != null and spell.is_ready() and not wizard.is_casting() \
		and _now - _last_cast >= profile.cast_pause


func _cast(slot: String, at: Vector2) -> bool:
	if wizard.cast(slot, at):
		_last_cast = _now
		return true
	return false


func _target_distance() -> float:
	return wizard.global_position.distance_to(target.global_position) if target else INF


# --- actions ----------------------------------------------------------------

## Default: keep the personality's preferred distance, circling the target.
func _score_reposition() -> float:
	return 0.3


func _do_reposition() -> void:
	if target == null:
		_goal = null
		return
	var from_target := wizard.global_position - target.global_position
	var d := from_target.length()
	if d < 1.0:
		from_target = Vector2.RIGHT
	var want := personality.preferred_distance
	if d < want:
		# Closer than it likes: back off only as much as its retreat bias says.
		want = lerpf(d, want, personality.retreat_bias)
	var dir := from_target.normalized().rotated(_strafe * 0.35)
	_goal = target.global_position + dir * want


func _score_fireball() -> float:
	var spell := wizard.get_spell("Q") as FireballSpell
	if target == null or spell == null or not _can_cast("Q"):
		return 0.0
	var d := _target_distance()
	if d > spell.max_range * 0.9:
		return 0.0
	return 0.6 + 0.2 * (1.0 - d / spell.max_range)


func _do_fireball() -> void:
	var spell := wizard.get_spell("Q") as FireballSpell
	_cast("Q", _aim_at(target, spell.speed))


# --- movement & aim -----------------------------------------------------------

func _steer() -> void:
	if wizard.is_casting() or wizard.attack_target != null:
		return
	wizard.move_dir = Vector2.ZERO
	wizard.move_target = _goal


## Where to aim at `w` for a projectile of `speed`: leads by the profile's
## lead_amount, then adds random aim error.
func _aim_at(w: Wizard, speed: float) -> Vector2:
	var from := wizard.global_position
	var at := w.global_position
	if speed > 0.0 and profile.lead_amount > 0.0:
		var t := from.distance_to(at) / speed
		at += w.velocity * t * profile.lead_amount
	var err := deg_to_rad(randf_range(-profile.aim_error_deg, profile.aim_error_deg))
	return from + (at - from).rotated(err)


## True if there is lava within `radius` of `p` (8 samples on a ring + centre).
func _lava_within(p: Vector2, radius: float) -> bool:
	var arena := wizard.arena
	if arena.is_lava_at(p):
		return true
	for i in 8:
		if arena.is_lava_at(p + Vector2.from_angle(i * TAU / 8.0) * radius):
			return true
	return false
