class_name StatsComponent
extends Node
## Base numbers for a character or enemy. Gear, skills and trade-offs will modify these later.

@export var max_health: int = 100
@export var attack_power: int = 10
@export var defense: int = 0

## Temporary damage boosts by source (&"booster", &"bloodrush"...), multiplied together,
## so a potion and a passive never overwrite each other.
var _damage_modifiers: Dictionary = {} # StringName -> float


## 1.0 (or any value <= 0) removes that source's modifier.
func set_damage_modifier(source: StringName, multiplier: float) -> void:
	if is_equal_approx(multiplier, 1.0) or multiplier <= 0.0:
		_damage_modifiers.erase(source)
	else:
		_damage_modifiers[source] = multiplier


func get_damage_multiplier() -> float:
	var total: float = 1.0
	for multiplier: float in _damage_modifiers.values():
		total *= multiplier
	return total


func get_attack_power() -> int:
	return roundi(attack_power * get_damage_multiplier())
