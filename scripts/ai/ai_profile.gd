class_name AIProfile
extends Resource
## One difficulty level for a bot: how well it perceives and executes.
## Independent of personality (what it likes to do).

## Seconds between decisions.
@export var think_interval := 0.3
## A projectile is only noticed once it has existed this long.
@export var reaction_delay := 0.25
## Random aim error, +/- degrees.
@export var aim_error_deg := 8.0
## 0 = aims where the target is, 1 = fully leads a moving target.
@export_range(0.0, 1.0) var lead_amount := 0.5
## Chance (rolled once per projectile) that the bot tries to dodge it.
@export_range(0.0, 1.0) var dodge_chance := 0.65
## Chance (rolled once per projectile) to shield it when it can't dodge.
@export_range(0.0, 1.0) var shield_reflect_chance := 0.4
## Extra wait after any cast before the next one.
@export var cast_pause := 0.4
## v0.10 human noise.
## 0..1: actions scoring within this fraction of the best are all candidates
## (weighted-random pick); 0 = always the top score.
@export_range(0.0, 1.0) var choice_spread := 0.2
## Reaction to each projectile is reaction_delay x [1 - j, 1 + 2j], rolled once.
@export_range(0.0, 1.0) var reaction_jitter := 0.35
## Lead is rolled per cast as lead_amount +/- this (0..1.2: sometimes too much).
@export var lead_jitter := 0.35
## Chance per think to hold back an attack for one think (a human hesitating).
@export_range(0.0, 1.0) var hesitate_chance := 0.07
