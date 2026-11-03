class_name WeatherComponent
extends Node
## Hot or cold weather on this hero (WeatherData). Rogue missions with ObjectiveData.biome_weather:
## the biome's weather over the whole map. Big maps: whatever WeatherZone the hero is standing in.
## Cold slows stamina refilling, heat makes every stamina cost higher; gear protection weakens both.
## The Player creates this, only on missions (never in camp).

signal weather_changed(weather: WeatherData) ## null = left it.

const CHECK_INTERVAL: float = 0.2 ## Seconds between zone checks.

var stamina: MeterComponent
var body: Node3D
var items: Array[ItemData] = [] ## Worn gear, for protection.
var weather: WeatherData = null ## Active right now. null = mild.

var _mission_weather: WeatherData = null
var _check_left: float = 0.0


func _ready() -> void:
	var objective: ObjectiveData = GameState.objective as ObjectiveData
	if objective and objective.biome_weather and GameState.biome():
		_mission_weather = GameState.biome().weather
	_set_weather(_mission_weather)


func protection() -> float:
	return EquipmentComponent.weather_protection(items, weather.kind) if weather else 0.0


## HUD line: "* Cold: stamina refills 40% slower (25% protected)". "" = mild.
func status_text() -> String:
	if weather == null:
		return ""
	var line: String = "%s %s: %s" % [weather.symbol, tr(weather.name_key), tr(weather.effect_key)]
	var protected: int = roundi(protection() * 100.0)
	if protected >= 100:
		return "%s %s: %s" % [weather.symbol, tr(weather.name_key), tr("HUD_WEATHER_IMMUNE")]
	return line + ("  " + tr("HUD_WEATHER_PROTECTED") % protected if protected > 0 else "")


func _physics_process(delta: float) -> void:
	if _mission_weather or body == null:
		return
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK_INTERVAL
	var found: WeatherData = null
	for zone: Node in get_tree().get_nodes_in_group(WeatherZone.GROUP):
		if (zone as WeatherZone).contains(body.global_position):
			found = (zone as WeatherZone).weather
			break
	if found != weather:
		_set_weather(found)


func _set_weather(new_weather: WeatherData) -> void:
	weather = new_weather
	var shield: float = protection()
	stamina.set_regen_modifier(&"weather", WeatherData.weakened(weather.stamina_regen_scale, shield) if weather else 1.0)
	stamina.set_cost_modifier(&"weather", WeatherData.weakened(weather.stamina_cost_scale, shield) if weather else 1.0)
	weather_changed.emit(weather)
