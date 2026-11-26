class_name AIMood
extends RefCounted
## A bot's mood for one round (v0.10), rolled on top of its personality so the
## same bot plays differently from round to round. Multiplies attack / defence
## scores, the preferred distance and the appetite for risk, and sets how long
## it watches before joining the fight ("wait and see").

## name: [attack, defend, distance, risk, watch_min, watch_max]
const TABLE := {
	"neutral": [1.0, 1.0, 1.0, 1.0, 0.0, 0.0],
	"aggressive": [1.1, 1.0, 0.9, 1.15, 0.0, 0.0], # v0.10 sims: 1.2/0.8/1.3 lost far too often
	"cautious": [0.85, 1.15, 1.25, 0.6, 2.0, 4.0],
	"opportunist": [1.0, 1.0, 1.15, 1.5, 3.0, 5.0],
}
const MOODS := ["aggressive", "cautious", "opportunist"]

var name := "neutral"
var attack_mult := 1.0
var defend_mult := 1.0
var distance_mult := 1.0
var risk_mult := 1.0
var watch_min := 0.0
var watch_max := 0.0


static func make(mood_name: String) -> AIMood:
	var m := AIMood.new()
	var v: Array = TABLE[mood_name]
	m.name = mood_name
	m.attack_mult = v[0]
	m.defend_mult = v[1]
	m.distance_mult = v[2]
	m.risk_mult = v[3]
	m.watch_min = v[4]
	m.watch_max = v[5]
	return m


static func neutral() -> AIMood:
	return make("neutral")


## One of MOODS, drawn by `odds` (mood -> weight; missing or empty = even).
static func roll(odds: Dictionary) -> AIMood:
	var total := 0.0
	for k in MOODS:
		total += float(odds.get(k, 0.0)) if not odds.is_empty() else 1.0
	if total <= 0.0:
		return make(MOODS[randi() % MOODS.size()])
	var r := randf() * total
	for k in MOODS:
		r -= float(odds.get(k, 0.0)) if not odds.is_empty() else 1.0
		if r <= 0.0:
			return make(k)
	return make(MOODS[-1])
