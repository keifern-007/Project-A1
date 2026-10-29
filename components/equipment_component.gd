class_name EquipmentComponent
extends Node
## Applies the saved loadout's stat bonuses to this character when it spawns.
## Must come after HealthComponent in the scene so it can resize health afterwards.
## (Phase 5: in co-op each player's loadout comes from their own profile.)

@export var stats: StatsComponent
@export var health: HealthComponent
@export var character: CharacterComponent ## Whose loadout to wear.


func _ready() -> void:
	var totals: Dictionary = EquipmentComponent.totals(stats.max_health, stats.attack_power, stats.defense,
		SaveManager.equipped_items(str(character.data.id)))
	stats.max_health = totals["max_health"]
	stats.attack_power = totals["attack_power"]
	stats.defense = totals["defense"]
	health.set_max_health(stats.max_health)


## Base stats + every item's bonuses. Also used by the Loadout panel to preview totals.
static func totals(max_health: int, attack_power: int, defense: int, items: Array[ItemData]) -> Dictionary:
	for item: ItemData in items:
		max_health += item.max_health
		attack_power += item.attack_power
		defense += item.defense
	return {
		"max_health": maxi(max_health, 1), # A trade-off can hurt, but never kill you outright.
		"attack_power": maxi(attack_power, 0),
		"defense": defense,
	}
