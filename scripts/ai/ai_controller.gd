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
const ACTIONS := ["dodge", "recover", "shield", "reposition", "fireball"]
## Bonus for sticking with the current action / target (stops jitter).
const KEEP_ACTION_BONUS := 0.1
const KEEP_TARGET_BONUS := 80.0
## "Near lava" for targeting: lava within this distance.
const NEAR_LAVA := 110.0
## A projectile is dangerous if it will pass this close within DANGER_TIME s.
const DANGER_RADIUS := 22.0
const DANGER_TIME := 0.8
## How far a dodge sidesteps.
const DODGE_STEP := 50.0
## Lava look-ahead for walking (seconds of walk).
const LAVA_LOOKAHEAD := 0.3

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
## Per projectile (instance id): [tries to dodge, would shield] rolled once.
var _rolls := {}
## The projectile the current think is reacting to (or null).
var _danger: Projectile = null


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
	_danger = _danger_projectile()
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


## Sidestep a projectile that is about to hit (if this one's roll says so).
func _score_dodge() -> float:
	if _danger == null or not _roll(_danger)[0] or _dodge_point(_danger) == null:
		return 0.0
	return 2.0


func _do_dodge() -> void:
	_goal = _dodge_point(_danger)


## Get off / away from lava. Highest when burning or flying toward it.
func _score_recover() -> float:
	if wizard.on_lava:
		return 3.0
	if _knocked_toward_lava():
		return 2.5
	if _lava_within(wizard.global_position, 50.0):
		return 0.8
	return 0.0


func _do_recover() -> void:
	var to_centre := (wizard.arena.get_center() - wizard.global_position).normalized()
	var urgent := wizard.on_lava or (_knocked_toward_lava() and wizard.knockback.length() > 250.0)
	var blink := wizard.get_spell("W")
	if urgent and blink and blink.is_ready() and not wizard.is_casting():
		# Emergencies skip the cast pause.
		if _cast("W", wizard.global_position + to_centre * 200.0):
			return
	_goal = wizard.global_position + to_centre * 120.0


## Bubble up against a projectile we won't (or can't) dodge, or an enemy
## winding up a spell right next to us.
func _score_shield() -> float:
	var shield := wizard.get_spell("R")
	if shield == null or not shield.is_ready() or wizard.is_casting() or wizard.is_shielded():
		return 0.0
	if _danger:
		var r: Array = _roll(_danger)
		var can_dodge: bool = r[0] and _dodge_point(_danger) != null
		if r[1] and not can_dodge:
			return 2.2
		return 0.0
	if target and target.is_casting() and _target_distance() < 60.0:
		return 0.9 if randf() < profile.shield_reflect_chance else 0.0
	return 0.0


func _do_shield() -> void:
	_cast("R", wizard.global_position)


# --- perception -------------------------------------------------------------

## Enemy projectiles the bot has had time to notice (older than its reaction
## delay). A projectile reflected by an enemy shield belongs to that enemy.
func _visible_projectiles() -> Array[Projectile]:
	var out: Array[Projectile] = []
	for n in get_tree().get_nodes_in_group("projectiles"):
		var p := n as Projectile
		if p and p.caster != wizard and p.age >= profile.reaction_delay:
			out.append(p)
	return out


## Closest-approach time and distance of projectile `p` to point `at`.
## Returns [t, distance]; t < 0 means it is moving away.
func _approach(p: Projectile, at: Vector2) -> Array:
	var v := p.direction * p.speed
	var rel := at - p.global_position
	if v.length_squared() < 1.0:
		return [-1.0, rel.length()]
	var t := rel.dot(v) / v.length_squared()
	return [t, (rel - v * t).length()]


## The visible projectile that will hit soonest, or null.
func _danger_projectile() -> Projectile:
	var best: Projectile = null
	var best_t := DANGER_TIME
	for p in _visible_projectiles():
		var a := _approach(p, wizard.global_position)
		if a[0] >= 0.0 and a[0] < best_t and a[1] < DANGER_RADIUS:
			best = p
			best_t = a[0]
	return best


## [tries to dodge, would shield] for projectile `p`, rolled once each.
func _roll(p: Projectile) -> Array:
	var id := p.get_instance_id()
	if not _rolls.has(id):
		if _rolls.size() > 64:
			_rolls.clear()
		_rolls[id] = [randf() < profile.dodge_chance, randf() < profile.shield_reflect_chance]
	return _rolls[id]


## A sidestep point off the projectile's path, on the side we're already on
## (or the other side if that one is lava). null if both sides are lava.
func _dodge_point(p: Projectile):
	var side := p.direction.orthogonal()
	var rel := wizard.global_position - p.global_position
	if rel.dot(side) < 0.0:
		side = -side
	for s in [side, -side]:
		var at: Vector2 = wizard.global_position + s * DODGE_STEP
		if not _lava_within(at, 16.0):
			return at
	return null


## True if the current knockback will carry us onto lava before it dies out.
func _knocked_toward_lava() -> bool:
	var kb := wizard.knockback
	if kb.length() < 80.0:
		return false
	var stop := wizard.global_position + kb / wizard.knockback_friction
	return wizard.arena.is_lava_at(stop)


# --- movement & aim -----------------------------------------------------------

func _steer() -> void:
	if wizard.is_casting() or wizard.attack_target != null:
		return
	wizard.move_dir = Vector2.ZERO
	wizard.move_target = _safe_step(_goal)


## Per-frame lava safety: if walking toward `goal` would put us on lava within
## LAVA_LOOKAHEAD seconds, walk along the edge instead (or toward the centre).
## Never applied while already on lava (then any way out is fine).
func _safe_step(goal):
	if goal == null or wizard.on_lava:
		return goal
	var pos := wizard.global_position
	var to: Vector2 = goal - pos
	if to.length() < 2.0:
		return goal
	var look := minf(to.length(), wizard.move_speed * LAVA_LOOKAHEAD)
	var dir := to.normalized()
	for angle in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8]:
		var d := dir.rotated(angle)
		if not _lava_within(pos + d * look, 12.0):
			return goal if angle == 0.0 else pos + d * look
	return null # boxed in: stand still rather than walk into lava


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
