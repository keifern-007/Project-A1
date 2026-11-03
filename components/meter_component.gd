class_name MeterComponent
extends Node
## A spendable pool that refills over time: mana, stamina (same node, different numbers).
## Optionally refills a chunk per enemy kill (mana). Values come from the character via configure().

signal changed(current: float, maximum: float)

@export var max_value: float = 100.0
@export var regen_per_second: float = 10.0
@export var per_kill: float = 0.0 ## Refill on every enemy kill. 0 = none.
@export var regen_pause: float = 0.0 ## Seconds after spending before it refills. 0 = no pause.

var current: float = 0.0

var _regen_mods: Dictionary = {} # source -> multiplier on refilling (a boss hazard, cold weather).
var _cost_mods: Dictionary = {} # source -> multiplier on every cost (hot weather).

var _pause_left: float = 0.0


func _ready() -> void:
	current = max_value
	EventBus.enemy_killed.connect(_on_enemy_killed) # Phase 5: only this player's kills.


## Sets the pool from character data and fills it.
func configure(maximum: float, regen: float, kill_refill: float = 0.0) -> void:
	max_value = maxf(maximum, 0.0)
	regen_per_second = regen
	per_kill = kill_refill
	current = max_value
	changed.emit(current, max_value)


func _physics_process(delta: float) -> void:
	_pause_left = maxf(_pause_left - delta, 0.0)
	if _pause_left == 0.0 and current < max_value and regen_per_second > 0.0:
		restore(regen_per_second * regen_multiplier() * delta)


## Named, so a boss hazard and the weather never overwrite each other. 1.0 = remove.
func set_regen_modifier(source: StringName, multiplier: float) -> void:
	if is_equal_approx(multiplier, 1.0):
		_regen_mods.erase(source)
	else:
		_regen_mods[source] = multiplier


func regen_multiplier() -> float:
	var result: float = 1.0
	for multiplier: float in _regen_mods.values():
		result *= multiplier
	return result


## Every cost is multiplied by this (has, spend and refund all use it). 1.0 = remove.
func set_cost_modifier(source: StringName, multiplier: float) -> void:
	if is_equal_approx(multiplier, 1.0):
		_cost_mods.erase(source)
	else:
		_cost_mods[source] = multiplier


## What a base cost really takes right now.
func cost_of(amount: float) -> float:
	for multiplier: float in _cost_mods.values():
		amount *= multiplier
	return amount


## The small allowance keeps rounding from refusing the last dodge of a bar.
func has(amount: float) -> bool:
	return current + 0.001 >= cost_of(amount)


## Spends `amount` (a base cost, see cost_of) if there's enough. Returns false (and spends nothing) otherwise.
func spend(amount: float) -> bool:
	if not has(amount):
		return false
	current = maxf(current - cost_of(amount), 0.0)
	_pause_left = regen_pause
	changed.emit(current, max_value)
	return true


## Gives back a base cost that was spent (a cancelled wind-up), as much as it really took.
func refund(amount: float) -> void:
	restore(cost_of(amount))


func restore(amount: float) -> void:
	if amount <= 0.0:
		return
	current = minf(current + amount, max_value)
	changed.emit(current, max_value)


func is_full() -> bool:
	return current >= max_value


func _on_enemy_killed(_enemy: Node) -> void:
	restore(per_kill)
