class_name BoosterComponent
extends Node
## Applies boosters: instant heals, and one timed damage boost at a time
## (picking up another refreshes it).

signal boost_started(booster: BoosterData)
signal boost_ended

@export var stats: StatsComponent
@export var health: HealthComponent
@export var mana: MeterComponent ## Optional: for mana potions.

var active_boost: BoosterData = null
var time_left: float = 0.0


func apply(booster: BoosterData) -> void:
	match booster.effect:
		BoosterData.Effect.HEAL:
			health.heal(roundi(booster.value))
		BoosterData.Effect.RESTORE_MANA:
			if mana:
				mana.restore(booster.value)
		BoosterData.Effect.DAMAGE_UP:
			active_boost = booster
			time_left = booster.duration
			stats.set_damage_modifier(&"booster", 1.0 + booster.value)
			boost_started.emit(booster)


func _physics_process(delta: float) -> void:
	if active_boost == null:
		return
	time_left -= delta
	if time_left <= 0.0:
		active_boost = null
		stats.set_damage_modifier(&"booster", 1.0)
		boost_ended.emit()
