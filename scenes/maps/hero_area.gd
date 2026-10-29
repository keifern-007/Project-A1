class_name HeroArea
extends Node3D
## A hero's own corner of the camp. The camp spawns that character here; while you play
## someone else, they idle here as an NPC. Rotate the node so -Z faces the campfire:
## the hero stands at the origin looking that way, with the decor behind them.

## Where the area sits on screen. The hero's card opens on the opposite side
## (left -> card on the right, right -> card on the left, middle -> right).
enum ScreenSide { LEFT, MIDDLE, RIGHT } # Not "Side": Godot has a global enum with that name.

@export var character: CharacterData
@export var side: ScreenSide = ScreenSide.MIDDLE


func _ready() -> void:
	add_to_group("hero_areas")


func card_on_right() -> bool:
	return side != ScreenSide.RIGHT
