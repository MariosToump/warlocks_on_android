class_name Shop
extends RefCounted
## Shop rules and purchases (milestone 7). Gold lives in `game.gold`
## (Wizard -> int). Static helpers, shared by the shop panel and the bots.
##
## - Spell upgrades: level 1 / 2 / 3 cost 10 / 15 / 20.
## - New spell: Homing Orb (slot D) 15.
## - Items, at most MAX_ITEMS, sold back for half: see ITEMS.

const UPGRADE_COSTS := [10, 15, 20] ## cost to reach level 1, 2, 3
const SLOTS := ["Q", "W", "E", "R", "D", "A"] ## upgrade order on the panel
const MAX_ITEMS := 2

const SPELLS := {
	"homing": {"name": "Homing Orb", "slot": "D", "price": 15,
			"script": preload("res://scripts/spells/homing_orb.gd"),
			"desc": "Slow orb that curves toward the nearest enemy."},
}

const ITEMS := {
	"boots": {"name": "Boots", "price": 15, "desc": "+15% move speed"},
	"cloak": {"name": "Stone Cloak", "price": 20, "desc": "-20% knockback taken"},
	"ring": {"name": "Fire Ring", "price": 10, "desc": "-50% lava damage"},
	"gem": {"name": "Focus Gem", "price": 20, "desc": "-10% cooldowns"},
}

## What each bot personality buys first (it walks the list again and again
## while it can afford something). "up:Q" = upgrade, "item:x", "spell:x".
const BOT_PRIORITY := {
	"Caster": ["up:Q", "item:gem", "spell:homing", "up:Q", "up:E", "item:ring", "up:R", "up:D", "up:W"],
	"Brawler": ["up:E", "item:cloak", "up:A", "item:boots", "up:R", "up:W", "up:Q", "spell:homing"],
	"Trickster": ["up:W", "item:boots", "spell:homing", "up:Q", "up:E", "item:gem", "up:D", "up:R"],
	"Bot": ["up:Q", "item:boots", "up:E", "spell:homing", "item:cloak", "up:W", "up:R"],
}


static func gold_of(game: Node, w: Wizard) -> int:
	return game.gold.get(w, 0)


static func _pay(game: Node, w: Wizard, amount: int) -> bool:
	if gold_of(game, w) < amount:
		return false
	game.gold[w] = gold_of(game, w) - amount
	return true


# --- upgrades -----------------------------------------------------------------

## Price of the next level of the spell in `slot`; -1 if none or maxed.
static func upgrade_cost(w: Wizard, slot: String) -> int:
	var s := w.get_spell(slot)
	if s == null or s.level >= UPGRADE_COSTS.size():
		return -1
	return UPGRADE_COSTS[s.level]


static func can_upgrade(game: Node, w: Wizard, slot: String) -> bool:
	var cost := upgrade_cost(w, slot)
	return cost >= 0 and gold_of(game, w) >= cost


static func upgrade(game: Node, w: Wizard, slot: String) -> bool:
	if not can_upgrade(game, w, slot):
		return false
	_pay(game, w, upgrade_cost(w, slot))
	w.get_spell(slot).level += 1
	return true


# --- new spells -----------------------------------------------------------------

static func has_spell(w: Wizard, id: String) -> bool:
	return w.get_spell(SPELLS[id].slot) != null


static func can_buy_spell(game: Node, w: Wizard, id: String) -> bool:
	return not has_spell(w, id) and gold_of(game, w) >= SPELLS[id].price


static func buy_spell(game: Node, w: Wizard, id: String) -> bool:
	if not can_buy_spell(game, w, id):
		return false
	_pay(game, w, SPELLS[id].price)
	var node := Node.new()
	node.set_script(SPELLS[id].script)
	node.name = SPELLS[id].slot
	w.get_node("Spells").add_child(node)
	return true


# --- items --------------------------------------------------------------------

## Anything at all `w` could buy right now (or items it could sell to swap)?
static func can_shop(game: Node, w: Wizard) -> bool:
	if not w.items.is_empty():
		return true
	for slot in SLOTS:
		if can_upgrade(game, w, slot):
			return true
	for id in SPELLS:
		if can_buy_spell(game, w, id):
			return true
	for id in ITEMS:
		if can_buy_item(game, w, id):
			return true
	return false


static func can_buy_item(game: Node, w: Wizard, id: String) -> bool:
	return not id in w.items and w.items.size() < MAX_ITEMS and gold_of(game, w) >= ITEMS[id].price


static func buy_item(game: Node, w: Wizard, id: String) -> bool:
	if not can_buy_item(game, w, id):
		return false
	_pay(game, w, ITEMS[id].price)
	w.items.append(id)
	apply_items(w)
	return true


static func sell_price(id: String) -> int:
	return int(ITEMS[id].price / 2)


static func sell_item(game: Node, w: Wizard, id: String) -> bool:
	if not id in w.items:
		return false
	w.items.erase(id)
	game.gold[w] = gold_of(game, w) + sell_price(id)
	apply_items(w)
	return true


## Item ids -> the wizard's multipliers.
static func apply_items(w: Wizard) -> void:
	w.speed_multiplier = 1.15 if "boots" in w.items else 1.0
	w.knockback_taken_multiplier = 0.8 if "cloak" in w.items else 1.0
	w.lava_multiplier = 0.5 if "ring" in w.items else 1.0
	w.cooldown_multiplier = 0.9 if "gem" in w.items else 1.0


## New match: base spells at level 0, no bought spells, no items.
static func clear(w: Wizard) -> void:
	for s in w.get_node("Spells").get_children():
		if s is Spell:
			s.level = 0
	for id in SPELLS:
		var bought := w.get_spell(SPELLS[id].slot)
		if bought:
			bought.get_parent().remove_child(bought)
			bought.queue_free()
	w.items.clear()
	apply_items(w)


# --- bots ---------------------------------------------------------------------

## Spend a bot's gold down its personality's wish list.
static func bot_shop(game: Node, w: Wizard) -> void:
	var ai := w.get_node_or_null("AIController") as AIController
	var who := ai.personality.personality_name if ai and ai.personality else "Bot"
	var wishes: Array = BOT_PRIORITY.get(who, BOT_PRIORITY.Bot)
	var bought := true
	while bought:
		bought = false
		for wish: String in wishes:
			var kind := wish.get_slice(":", 0)
			var id := wish.get_slice(":", 1)
			var ok := false
			match kind:
				"up":
					ok = upgrade(game, w, id)
				"item":
					ok = buy_item(game, w, id)
				"spell":
					ok = buy_spell(game, w, id)
			if ok:
				bought = true
				break # start the list again from the top
