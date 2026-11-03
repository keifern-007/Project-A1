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
const MIN_STAMINA: float = 10.0 ## Gear can lower stamina, but always leaves enough to act.

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


## Whole dodges a full stamina bar pays for. The Gear Rack shows this. A dodge's cost comes from
## the hero's own stamina, so gear that adds stamina adds dodges.
static func dodges_with(data: CharacterData, load_amount: float, items: Array[ItemData]) -> int:
	var bars: float = max_stamina_with(data.max_stamina, items) / data.max_stamina
	return floori(data.dodges_per_bar * bars / dodge_cost_multiplier(load_amount) + 0.001)


static func max_stamina_with(base: float, items: Array[ItemData]) -> float:
	var total: float = base
	for item: ItemData in items:
		total += item.max_stamina
	return maxf(total, MIN_STAMINA)


static func max_mana_with(base: float, items: Array[ItemData]) -> float:
	var total: float = base
	for item: ItemData in items:
		total += item.max_mana
	return maxf(total, 0.0)


## Element.Type -> damage multiplier, added up over everything worn. Missing = 1.0.
static func element_multipliers(items: Array[ItemData]) -> Dictionary:
	var fire: int = 0
	var ice: int = 0
	var poison: int = 0
	for item: ItemData in items:
		fire += item.fire_power
		ice += item.ice_power
		poison += item.poison_power
	return {
		Element.Type.FIRE: maxf(1.0 + fire / 100.0, 0.0),
		Element.Type.ICE: maxf(1.0 + ice / 100.0, 0.0),
		Element.Type.POISON: maxf(1.0 + poison / 100.0, 0.0),
	}


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


## Share of this weather kind blocked by what's worn (0..1).
static func weather_protection(items: Array[ItemData], kind: WeatherData.Kind) -> float:
	var total: int = 0
	for item: ItemData in items:
		total += item.cold_protection if kind == WeatherData.Kind.COLD else item.heat_protection
	return clampf(total / 100.0, 0.0, 1.0)
