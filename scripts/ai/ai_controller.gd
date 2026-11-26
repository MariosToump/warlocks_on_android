class_name AIController
extends Node
## Drives the parent Wizard as a bot (milestone 5), the way PlayerController
## drives the player: it only sets move_target and calls cast() / attack().
##
## Every think tick (profile.think_interval) it picks a target, scores every
## action for the current situation, multiplies each score by the
## personality's weight and runs one of the near-best (weighted-random, v0.10). Cast actions fire once;
## movement actions set a goal that is followed every physics frame.

## Every action has _score_<name>() -> float and _do_<name>() -> void.
const ACTIONS := ["dodge", "recover", "shield", "reposition", "fireball", "lightning", "staff", "blink_in", "homing", "rockwall"]
## Actions that attack (held back by hesitation, the opening watch, moods).
const ATTACKS := ["fireball", "lightning", "staff", "blink_in", "homing"]
## Bonus for sticking with the current action / target (stops jitter).
const KEEP_ACTION_BONUS := 0.1
const KEEP_TARGET_BONUS := 80.0
## Whoever hit us in the last RETALIATE_TIME s counts this much closer.
const RETALIATE_BONUS := 300.0
const RETALIATE_TIME := 4.0
## Each round the target has won this match makes it this much "closer".
const LEADER_BONUS := 180.0
## "Near lava" for targeting: lava within this distance.
const NEAR_LAVA := 110.0
## A projectile is dangerous if it will pass this close within DANGER_TIME s.
const DANGER_RADIUS := 22.0
const DANGER_TIME := 0.8
## How far a dodge sidesteps.
const DODGE_STEP := 50.0
## Lava look-ahead for walking (seconds of walk).
const LAVA_LOOKAHEAD := 0.3
## Staff: start walking in to swing from this far away.
const STAFF_ENGAGE := 90.0
## Lightning is used up to this distance (its range is 230).
const LIGHTNING_REACH := 215.0
## "Lava behind the target": this far past it, seen from the attacker.
const BEHIND := 80.0
## Opening watch: attacks count this much, and it keeps at least this far off.
const WATCH_ATTACK := 0.15
const WATCH_DISTANCE := 260.0
## An enemy this exposed ends the watch at once.
const WATCH_BREAK_OPPORTUNITY := 0.6
const DEFENCES := ["dodge", "shield", "rockwall"]

@export var profile: AIProfile
@export var personality: AIPersonality
@export var debug_draw := false

@onready var wizard: Wizard = get_parent()

var target: Wizard = null
var current_action := ""
## This round's mood (neutral until the game calls reset()).
var mood := AIMood.neutral()

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
## Per enemy (instance id) mid-cast: shield against this cast? Rolled once.
var _cast_rolls := {}
## How long we've been flying toward lava without having reacted yet.
var _knocked_for := 0.0
## The projectile the current think is reacting to (or null).
var _danger: Projectile = null
## Opening watch ends at this _now (only advances while the brain is on).
var _watch_until := 0.0
## wizard.last_hit_at when the watch started: a new hit ends it.
var _watch_hit_mark := 0.0
var _debug: DebugView


func _ready() -> void:
	if profile == null:
		profile = AIProfile.new()
	if personality == null:
		personality = AIPersonality.new()
	_strafe = 1.0 if randf() < 0.5 else -1.0
	_think_left = randf() * profile.think_interval # bots don't think in lockstep
	if debug_draw:
		_debug = DebugView.new()
		_debug.ai = self
		_debug.top_level = true
		_debug.z_index = 20
		wizard.add_child.call_deferred(_debug)


## Forget everything from the last round (the game calls this at round start).
func reset() -> void:
	target = null
	current_action = ""
	_goal = null
	_danger = null
	_rolls.clear()
	_cast_rolls.clear()
	_knocked_for = 0.0
	_think_left = randf() * profile.think_interval
	_start_mood(AIMood.roll(personality.mood_odds))


## Take `m` as this round's mood and start its opening watch.
func _start_mood(m: AIMood) -> void:
	mood = m
	_watch_until = _now + randf_range(m.watch_min, m.watch_max)
	_watch_hit_mark = wizard.last_hit_at if wizard else 0.0


## Still in the opening "wait and see"?
func watching() -> bool:
	return _now < _watch_until


## Distance it wants from its target: personality x mood, and well out of
## reach while watching.
func preferred_distance() -> float:
	var d := personality.preferred_distance * mood.distance_mult
	return maxf(d, WATCH_DISTANCE) if watching() else d


## 0..1: how exposed `w` is right now (filled in by the risk task).
func opportunity(_w: Wizard) -> float:
	return 0.0


func _physics_process(delta: float) -> void:
	if not wizard.alive or wizard.arena == null:
		target = null
		_goal = null
		return
	if target != null and not is_instance_valid(target):
		target = null
	_now += delta
	# Being knocked toward lava is felt between thinks too (after half the
	# reaction delay), so slow thinkers don't fly in waiting for their tick.
	if current_action != "recover" and _knocked_toward_lava():
		_knocked_for += delta
		if _knocked_for >= profile.reaction_delay * 0.5:
			_think_left = 0.0
	else:
		_knocked_for = 0.0
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
	if watching() and (wizard.last_hit_at != _watch_hit_mark 			or (target and opportunity(target) >= WATCH_BREAK_OPPORTUNITY)):
		_watch_until = _now # hit, or someone left wide open: join in
	_danger = _danger_projectile()
	for id in _cast_rolls.keys():
		var w := instance_from_id(id) as Wizard
		if w == null or not w.is_casting():
			_cast_rolls.erase(id)
	var scores := {}
	for action in ACTIONS:
		var s: float = call("_score_" + action) * personality.weight(action)
		if s <= 0.0:
			continue
		if action in ATTACKS:
			s *= mood.attack_mult * (WATCH_ATTACK if watching() else 1.0)
		elif action in DEFENCES:
			s *= mood.defend_mult
		if action == current_action:
			s += KEEP_ACTION_BONUS
		scores[action] = s
	var best := _choose(scores)
	if best in ATTACKS and randf() < profile.hesitate_chance:
		best = "" # a moment's hesitation: keep walking, don't attack yet
	current_action = best
	if best != "staff" and wizard.attack_target != null:
		wizard.attack(null) # stop chasing with the staff
	if best != "":
		call("_do_" + best)


## Weighted-random pick among the actions scoring within
## profile.choice_spread of the best (the best stays the most likely).
## Getting off lava is never left to chance.
func _choose(scores: Dictionary) -> String:
	var best := ""
	var best_s := -INF
	for a in scores:
		if scores[a] > best_s:
			best_s = scores[a]
			best = a
	if best == "" or best == "recover":
		return best
	var cut := best_s * (1.0 - profile.choice_spread)
	var pool := {}
	var total := 0.0
	for a in scores:
		if scores[a] >= cut:
			pool[a] = scores[a] - cut + 0.02 * best_s
			total += pool[a]
	var r := randf() * total
	for a in pool:
		r -= pool[a]
		if r <= 0.0:
			return a
	return best


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
		cost -= w.match_wins * LEADER_BONUS
		if _lava_within(w.global_position, NEAR_LAVA):
			cost -= 150.0
		if w == target:
			cost -= KEEP_TARGET_BONUS
		if w == wizard.last_attacker and Time.get_ticks_msec() / 1000.0 - wizard.last_hit_at < RETALIATE_TIME:
			cost -= RETALIATE_BONUS
		if cost < best_cost:
			best_cost = cost
			best = w
	return best


## A rock between us and the target would eat the spell.
func _rock_in_the_way() -> bool:
	return Prop.blocks(get_tree(), wizard.global_position, target.global_position)


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
	if target == null:
		return 0.3
	var off := absf(_target_distance() - preferred_distance())
	return 0.3 + 0.3 * clampf(off / 300.0, 0.0, 1.0)


func _do_reposition() -> void:
	if target == null:
		# Nobody to fight: drift around the middle, the safest place.
		if _goal == null or wizard.global_position.distance_to(_goal) < 20.0 				or _goal.distance_to(wizard.arena.get_center()) > 160.0:
			_goal = wizard.arena.get_center() + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 150.0)
		return
	var from_target := wizard.global_position - target.global_position
	var d := from_target.length()
	if d < 1.0:
		from_target = Vector2.RIGHT
	var want := preferred_distance()
	if d < want:
		# Closer than it likes: back off only as much as its retreat bias says.
		want = lerpf(d, want, personality.retreat_bias)
	var dir := from_target.normalized().rotated(_strafe * 0.35)
	_goal = target.global_position + dir * want


## Homing Orb (slot D, bought in the shop): slow but it curves, so good at
## mid/long range; useless point-blank (it can't turn in time).
func _score_homing() -> float:
	var spell := wizard.get_spell("D") as HomingOrbSpell
	if target == null or spell == null or not _can_cast("D") or target.is_shielded():
		return 0.0
	var d := _target_distance()
	if d < 140.0 or d > 700.0:
		return 0.0
	return 0.85


## Rock Wall (if bought): cover from a spell we've seen coming when the
## shield is down; a little less than a clean dodge.
func _score_rockwall() -> float:
	if wizard.get_spell("F") == null or not _can_cast("F") or _danger == null:
		return 0.0
	if not _roll(_danger)[0] or (wizard.get_spell("R") and wizard.get_spell("R").is_ready()):
		return 0.0
	if _danger.global_position.distance_to(wizard.global_position) < 70.0:
		return 0.0 # too late, the wall would come up behind it
	return 1.9


func _do_rockwall() -> void:
	if _danger and is_instance_valid(_danger):
		_cast("F", _danger.global_position)


func _do_homing() -> void:
	_cast("D", target.global_position)


func _score_fireball() -> float:
	var spell := wizard.get_spell("Q") as FireballSpell
	if target == null or spell == null or not _can_cast("Q") or target.is_shielded():
		return 0.0
	var d := _target_distance()
	if d > spell.max_range * 0.9 or _rock_in_the_way():
		return 0.0
	return 0.6 + 0.2 * d / spell.max_range # better at range; lightning covers close


func _do_fireball() -> void:
	var spell := wizard.get_spell("Q") as FireballSpell
	_cast("Q", _aim_at(target, spell.speed))


## Instant short bolt with big knockback: best when there's lava behind them.
func _score_lightning() -> float:
	if target == null or not _can_cast("E") or target.is_shielded():
		return 0.0
	if _target_distance() > LIGHTNING_REACH or _rock_in_the_way():
		return 0.0
	var d := _target_distance()
	if _lava_behind(target, wizard.global_position):
		return 1.2 + 0.5 * (1.0 - d / LIGHTNING_REACH)
	var s := 0.7 + 0.5 * (1.0 - d / LIGHTNING_REACH)
	# Blasting them away is pointless for a bot that's trying to close in.
	if d > preferred_distance() + 60.0:
		s *= 0.4
	return s


func _do_lightning() -> void:
	_cast("E", _aim_at(target, 0.0))


## Walk in and swing (Wizard.attack chases and keeps swinging).
func _score_staff() -> float:
	if target == null or wizard.get_spell("A") == null or target.is_shielded():
		return 0.0
	var d := _target_distance()
	if d > STAFF_ENGAGE or not _reachable(target):
		return 0.0
	return 0.8 + (0.4 if _lava_behind(target, wizard.global_position) else 0.0)


func _do_staff() -> void:
	_goal = null
	if wizard.attack_target != target:
		wizard.attack(target)


## Blink next to a target that stands near lava, on its far side from the
## lava, then shove it in with the staff.
func _score_blink_in() -> float:
	if target == null or not _can_cast("W") or target.is_shielded() or target.on_lava:
		return 0.0
	var d := _target_distance()
	if d < 80.0 or d > 220.0 or _blink_in_point() == null:
		return 0.0
	return 1.0


func _do_blink_in() -> void:
	var at = _blink_in_point()
	if at != null and _cast("W", at):
		wizard.attack(target)


## 26 px from the target on the side away from its nearest lava, or null if
## the target isn't near lava or that spot is lava itself.
func _blink_in_point():
	var lava_dir := Vector2.ZERO
	for i in 8:
		var d := Vector2.from_angle(i * TAU / 8.0)
		if _unsafe(target.global_position + d * NEAR_LAVA):
			lava_dir += d
	if lava_dir == Vector2.ZERO:
		return null
	var at := target.global_position - lava_dir.normalized() * 26.0
	var blink := wizard.get_spell("W") as BlinkSpell
	if _lava_within(at, 12.0) or blink == null 			or wizard.global_position.distance_to(at) > blink.max_distance:
		return null
	return at


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
	if wizard.arena.is_lava_soon(wizard.global_position):
		return 2.6
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
	if not _can_cast("R") or wizard.is_shielded():
		return 0.0
	if _danger:
		var r: Array = _roll(_danger)
		var can_dodge: bool = r[0] and _dodge_point(_danger) != null
		if r[1] and not can_dodge:
			return 2.2
		# Could dodge, but reflecting it back is nicer: personalities that
		# like the shield (weight > ~1.1) pick this over dodging.
		return 1.8 if r[1] else 0.0
	if target and target.is_casting() and _target_distance() < 60.0:
		var id := target.get_instance_id()
		if not _cast_rolls.has(id):
			_cast_rolls[id] = randf() < profile.shield_reflect_chance
		return 0.9 if _cast_rolls[id] else 0.0
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
		if p and p.caster != wizard and p.age >= _roll(p)[2]:
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


## [tries to dodge, would shield, reaction time] for projectile `p`, rolled
## once each (the reaction varies: sometimes quick, sometimes slow).
func _roll(p: Projectile) -> Array:
	var id := p.get_instance_id()
	if not _rolls.has(id):
		if _rolls.size() > 64:
			for old in _rolls.keys():
				if not is_instance_id_valid(old):
					_rolls.erase(old)
		var j := profile.reaction_jitter
		_rolls[id] = [randf() < profile.dodge_chance, randf() < profile.shield_reflect_chance,
			profile.reaction_delay * randf_range(1.0 - j, 1.0 + 2.0 * j)]
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


## True if we can walk up to `w` without crossing lava (it isn't standing in
## lava and the way there is clear).
func _reachable(w: Wizard) -> bool:
	if w.on_lava:
		return false
	var at := w.global_position
	return _safe_step(at) == at


## True if `w`, hit from `from`, would fly toward lava.
func _lava_behind(w: Wizard, from: Vector2) -> bool:
	var dir := (w.global_position - from).normalized()
	return _unsafe(w.global_position + dir * BEHIND)


## True if the current knockback will carry us onto lava before it dies out.
func _knocked_toward_lava() -> bool:
	var kb := wizard.knockback
	if kb.length() < 80.0:
		return false
	var stop := wizard.global_position + kb / wizard.knockback_friction
	return _unsafe(stop)


# --- movement & aim -----------------------------------------------------------

func _steer() -> void:
	if wizard.attack_target != null:
		# Wizard chases its attack target on its own, so check that path too.
		var chase := wizard.attack_target.global_position
		var safe = _safe_step(chase)
		if safe == chase:
			return
		wizard.attack(null)
		_goal = safe
	if wizard.is_casting():
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
	# Boxed in: head for the middle of the arena (always stone) instead.
	var to_centre := (wizard.arena.get_center() - pos).normalized()
	return pos + to_centre * look


## Where to aim at `w` for a projectile of `speed`: leads by about the
## profile's lead_amount (rolled per cast, sometimes too much), then adds a
## bell-curve aim error (mostly close, now and then properly wide).
func _aim_at(w: Wizard, speed: float) -> Vector2:
	var from := wizard.global_position
	var at := w.global_position
	if speed > 0.0:
		var lead := clampf(profile.lead_amount + randf_range(-profile.lead_jitter, profile.lead_jitter), 0.0, 1.2)
		var t := from.distance_to(at) / speed
		at += w.velocity * t * lead
	var a := profile.aim_error_deg
	var err := deg_to_rad(clampf(randfn(0.0, a * 0.6), -2.0 * a, 2.0 * a))
	return from + (at - from).rotated(err)


## Lava now, or stone the shrinking edge is about to swallow.
func _unsafe(p: Vector2) -> bool:
	return wizard.arena.is_lava_at(p) or wizard.arena.is_lava_soon(p)


## True if there is (soon) lava within `radius` of `p` (8 samples on a ring
## + centre).
func _lava_within(p: Vector2, radius: float) -> bool:
	if _unsafe(p):
		return true
	for i in 8:
		if _unsafe(p + Vector2.from_angle(i * TAU / 8.0) * radius):
			return true
	return false


## debug_draw: the current action above the bot and a line to its target.
class DebugView extends Node2D:
	var ai: AIController

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(ai) or not ai.wizard.alive:
			return
		var p := ai.wizard.global_position
		if ai.target:
			draw_line(p, ai.target.global_position, Color(1, 1, 0, 0.4), 1.0)
		draw_string(ThemeDB.fallback_font, p + Vector2(-30, -44), ai.current_action,
			HORIZONTAL_ALIGNMENT_CENTER, 60, 10, Color.YELLOW)
