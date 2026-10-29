class_name DropEntry
extends Resource
## One line of an enemy's loot table: what can drop, how likely, how many.
## Set either material or booster.

@export var material: MaterialData
@export var booster: BoosterData
@export_range(0.0, 1.0) var chance: float = 0.25
@export var min_amount: int = 1
@export var max_amount: int = 1
