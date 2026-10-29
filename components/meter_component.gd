class_name MeterComponent
extends Node
## A spendable pool that refills over time: mana, stamina (same node, different numbers).
## Optionally refills a chunk per enemy kill (mana). Values come from the character via configure().

signal changed(current: float, maximum: float)

@export var max_value: float = 100.0
@export var regen_per_second: float = 10.0
@export var per_kill: float = 0.0 ## Refill on every enemy kill. 0 = none.

var current: float = 0.0


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
	if current < max_value and regen_per_second > 0.0:
		restore(regen_per_second * delta)


func has(amount: float) -> bool:
	return current >= amount


## Spends `amount` if there's enough. Returns false (and spends nothing) otherwise.
func spend(amount: float) -> bool:
	if not has(amount):
		return false
	current -= amount
	changed.emit(current, max_value)
	return true


func restore(amount: float) -> void:
	if amount <= 0.0:
		return
	current = minf(current + amount, max_value)
	changed.emit(current, max_value)


func is_full() -> bool:
	return current >= max_value


func _on_enemy_killed(_enemy: Node) -> void:
	restore(per_kill)
