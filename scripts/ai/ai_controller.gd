class_name AIController
extends Node
## Drives the parent Wizard as a bot (milestone 5).

@export var profile: AIProfile
@export var personality: AIPersonality
@export var debug_draw := false

@onready var wizard: Wizard = get_parent()
