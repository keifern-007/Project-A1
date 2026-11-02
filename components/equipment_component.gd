class_name EquipmentComponent
extends Node
## Applies the saved loadout's stat bonuses to this character when it spawns.
## Must come after HealthComponent in the scene so it can resize health afterwards.
## (Phase 5: in co-op each player's loadout comes from their own profile.)

const FULL_LOAD: float = 1.0 ## Most armor weight that counts. The heaviest full set is exactly this.
const DODGE_COST_AT_FULL_LOAD: float = 1.0 ## +100%: a full load halves your dodges.
const ATTACK_COST_AT_FULL_LOAD: float = 0.25 ## +25% basic attack stamina: armor only nudges this.
## +10% wind-up. Stays well below weapon weight (x0.7 to x1.6), which is what should really decide it.
const WINDUP_AT_FULL_LOAD: float = 0.1

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


## Everything worn, added up: 0 = no armor, 1 = a full load.
static func armor_load(items: Array[ItemData]) -> float:
	var total: float = 0.0
	for item: ItemData in items:
		total += item.armor_weight
	return minf(total, FULL_LOAD)


static func dodge_cost_multiplier(load_amount: float) -> float:
	return 1.0 + load_amount * DODGE_COST_AT_FULL_LOAD


static func attack_cost_multiplier(load_amount: float) -> float:
	return 1.0 + load_amount * ATTACK_COST_AT_FULL_LOAD


static func windup_multiplier(load_amount: float) -> float:
	return 1.0 + load_amount * WINDUP_AT_FULL_LOAD


## Whole dodges a full stamina bar pays for. The Gear Rack shows this.
static func dodges_with(dodges_per_bar: float, load_amount: float) -> int:
	return floori(dodges_per_bar / dodge_cost_multiplier(load_amount) + 0.001)


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
