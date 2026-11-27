class_name Boomerang
extends Projectile
## The Boomerang spell's blade (v0.12): flies `out_range` px, then homes back
## to its caster and is caught. Passes through wizards, hitting each at most
## once going out and once coming back (the return hit pushes the way the
## blade is flying, so toward the caster). Rocks end it; a shield turns it
## like any projectile, and it then returns to the shielder.

## How far it flies before turning back.
var out_range := 420.0
var returning := false
## Wizards already hit on this leg (instance ids).
var _hit := {}
## Safety: a blade that can't get home in this long just fades.
const MAX_LIFE := 5.0
## Caught when it gets this close to its caster on the way back.
const CATCH := 20.0


func _ready() -> void:
	super()
	add_to_group("boomerangs")
	sprite.rotation = 0.0 # the frames spin on their own


func _physics_process(delta: float) -> void:
	if _done or _frozen():
		return
	age += delta
	if caster == null or not is_instance_valid(caster) or not caster.alive or age > MAX_LIFE:
		queue_free()
		return
	if returning:
		var home := caster.global_position - global_position
		if home.length() < CATCH:
			queue_free()
			return
		direction = home.normalized()
	var step := direction * speed * delta
	position += step
	_travelled += step.length()
	var owner_before := caster
	_check_shields()
	if caster != owner_before:
		returning = false # bounced: flies out from the shield again
		_hit.clear()
	if not returning and _travelled >= out_range:
		returning = true
		_hit.clear()
		Sfx.play_at("boomerang_return", global_position)


func _on_body_entered(body: Node) -> void:
	if _done:
		return
	if body is Prop:
		(body as Prop).push(direction * knockback, caster)
		_explode(impact_scale)
		return
	if body == caster or not (body is Wizard) or not body.alive:
		return
	var w := body as Wizard
	if w.is_shielded() or _hit.has(w.get_instance_id()):
		return
	_hit[w.get_instance_id()] = true
	w.take_damage(damage, caster)
	w.apply_knockback(direction * knockback)
	w.flash_hit(direction)
	Sfx.play_at("hit", global_position, -4.0)
