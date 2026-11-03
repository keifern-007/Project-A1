class_name WeatherData
extends Resource
## Hot or cold weather that wears heroes down, saved as a .tres in resources/weather/.
## Rogue maps: BiomeData.weather, over the whole map, on missions with ObjectiveData.biome_weather.
## Big maps: only inside WeatherZones. Gear with that kind's protection weakens it (100% = no effect).
## Run by the hero's WeatherComponent; the HUD and Mission Board say it in words.

enum Kind { COLD, HEAT }

@export var kind: Kind = Kind.COLD
@export var name_key: String = "" ## "Cold"
@export var effect_key: String = "" ## What it does, e.g. "stamina refills 40% slower".
@export var symbol: String = "*" ## ASCII, shown before the name, so color is never the only cue.
## Full strength (no protection). 0.6 = stamina refills at 60% speed.
@export var stamina_regen_scale: float = 1.0
## Full strength. 1.3 = every stamina cost (attacks, dodges, physical skills) is 30% higher.
@export var stamina_cost_scale: float = 1.0


## Translation key of the gear stat that protects against it.
func protection_key() -> String:
	return "STAT_COLD_PROTECTION" if kind == Kind.COLD else "STAT_HEAT_PROTECTION"


## Strength left after `protection` (0..1): halfway between no effect and full at 50%.
static func weakened(scale: float, protection: float) -> float:
	return lerpf(scale, 1.0, clampf(protection, 0.0, 1.0))
