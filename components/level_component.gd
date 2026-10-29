class_name LevelComponent
extends Node
## In-run XP and levels. Each level-up raises stats and heals a little.
## Levels reset every run; permanent progression is Phase 3's skill tree.

signal xp_changed(xp: int, xp_needed: int, level: int)
signal leveled_up(level: int)

@export var stats: StatsComponent
@export var health: HealthComponent

@export_group("Curve")
@export var base_xp: int = 20 ## XP needed for level 2.
@export var xp_growth: int = 15 ## Extra XP needed for each level after that.

@export_group("Per Level")
@export var health_per_level: int = 10
@export var attack_per_level: int = 2

var level: int = 1
var xp: int = 0


func xp_to_next() -> int:
	return base_xp + xp_growth * (level - 1)


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		_level_up()
	xp_changed.emit(xp, xp_to_next(), level)


func _level_up() -> void:
	level += 1
	stats.max_health += health_per_level
	stats.attack_power += attack_per_level
	health.set_max_health(stats.max_health, false)
	health.heal(health_per_level)
	leveled_up.emit(level)
