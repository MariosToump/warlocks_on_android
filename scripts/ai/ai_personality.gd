class_name AIPersonality
extends Resource
## What a bot likes to do: a multiplier per action score, and how far from
## its target it likes to fight. Independent of difficulty.

@export var personality_name := "Bot"
## Centre-to-centre distance the bot tries to keep from its target.
@export var preferred_distance := 180.0
## Action name -> weight. Missing actions count as 1.0.
@export var weights := {
	"dodge": 1.0, "recover": 1.0, "shield": 1.0, "fireball": 1.0,
	"lightning": 1.0, "staff": 1.0, "blink_in": 1.0, "reposition": 1.0,
}
## 0..1: how readily it backs off when an enemy comes closer than preferred.
@export_range(0.0, 1.0) var retreat_bias := 0.5


func weight(action: String) -> float:
	return float(weights.get(action, 1.0))


## v0.10: mood odds per round (mood -> weight; see AIMood) and how readily it
## goes for an opening (scales the opportunity bonus).
@export var mood_odds := {"aggressive": 1.0, "cautious": 1.0, "opportunist": 1.0}
@export var risk_appetite := 0.8
