class_name HealthComponent
extends Node
## Tracks HP. Doesn't know what hit it or what dying means — it just emits signals.

signal health_changed(current: int, maximum: int)
signal damaged(amount: int)
signal died

## Optional. If set, max_health comes from the stats.
@export var stats: StatsComponent
@export var max_health: int = 100

var current: int = 0
var is_dead: bool = false


func _ready() -> void:
	if stats:
		max_health = stats.max_health
	current = max_health


## Changes max HP (enemy data, gear). refill=true also tops current HP up to the new max.
func set_max_health(value: int, refill: bool = true) -> void:
	max_health = maxi(value, 1)
	current = max_health if refill else mini(current, max_health)
	health_changed.emit(current, max_health)


func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	current = maxi(current - amount, 0)
	damaged.emit(amount)
	health_changed.emit(current, max_health)
	if current == 0:
		is_dead = true
		died.emit()


func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	current = mini(current + amount, max_health)
	health_changed.emit(current, max_health)
