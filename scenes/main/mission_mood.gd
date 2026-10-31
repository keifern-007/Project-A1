class_name MissionMood
extends Node
## Re-lights the loaded map for the mission's MoodData (stormy boss fights, bright gathering):
## tints its sky, sun and fog, adds weather and, for storms, the odd lightning strike.
## Purely visual: it uses its own RNG, never GameState.rng, so co-op runs stay in sync.

signal lightning_struck ## Hook for the thunder sound.

const FLASH_RISE: float = 0.04
const FLASH_FALL: float = 0.3

var data: MoodData
var _sun: DirectionalLight3D
var _sun_energy: float = 1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _lightning_left: float = 0.0
var _flash_tween: Tween


## Applies `mood` to the map scene `world` and returns the node that keeps it running (add it to the tree).
static func create(mood: MoodData, world: Node, biome: BiomeData) -> MissionMood:
	var mood_node: MissionMood = MissionMood.new()
	mood_node.name = "MissionMood"
	mood_node.data = mood
	mood_node._apply(world, biome)
	return mood_node


func _apply(world: Node, biome: BiomeData) -> void:
	var env_node: WorldEnvironment = _first_of(world, "WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment:
		env_node.environment = _moody_environment(env_node.environment)
	_sun = _first_of(world, "DirectionalLight3D") as DirectionalLight3D
	if _sun:
		_sun.light_energy *= data.sun_energy_multiplier
		_sun.light_color = _sun.light_color.lerp(data.sun_color, data.sun_color_blend)
		_sun_energy = _sun.light_energy
	var weather: PackedScene = data.weather
	if data.use_biome_storm_weather and biome and biome.storm_weather:
		weather = biome.storm_weather
	if weather:
		world.add_child(weather.instantiate())
	_rng.randomize()
	_schedule_lightning()


# A copy, so the map's own .tscn resources are never changed.
func _moody_environment(source: Environment) -> Environment:
	var env: Environment = source.duplicate()
	if env.sky and env.sky.sky_material is ProceduralSkyMaterial and data.sky_blend > 0.0:
		env.sky = env.sky.duplicate()
		var sky: ProceduralSkyMaterial = env.sky.sky_material.duplicate()
		sky.sky_top_color = sky.sky_top_color.lerp(data.sky_top_color, data.sky_blend)
		sky.sky_horizon_color = sky.sky_horizon_color.lerp(data.sky_horizon_color, data.sky_blend)
		sky.ground_horizon_color = sky.ground_horizon_color.lerp(data.sky_horizon_color, data.sky_blend)
		env.sky.sky_material = sky
	env.ambient_light_energy *= data.ambient_energy_multiplier
	env.ambient_light_color = env.ambient_light_color.lerp(data.fog_color, data.fog_blend * 0.5)
	if data.fog_density_min > 0.0:
		env.fog_enabled = true
		env.fog_density = maxf(env.fog_density, data.fog_density_min)
	env.fog_light_color = env.fog_light_color.lerp(data.fog_color, data.fog_blend)
	if not is_equal_approx(data.saturation_multiplier, 1.0):
		if not env.adjustment_enabled:
			env.adjustment_enabled = true
			env.adjustment_saturation = 1.0
			env.adjustment_brightness = 1.0
			env.adjustment_contrast = 1.0
		env.adjustment_saturation *= data.saturation_multiplier
	return env


func _process(delta: float) -> void:
	if _lightning_left <= 0.0:
		return
	_lightning_left -= delta
	if _lightning_left <= 0.0:
		_strike()
		_schedule_lightning()


func _schedule_lightning() -> void:
	if data.lightning_interval_max <= 0.0:
		_lightning_left = 0.0
		return
	_lightning_left = _rng.randf_range(data.lightning_interval_min, data.lightning_interval_max)


## One single flash (never a strobe), skipped entirely with reduce_flashing. Thunder plays either way.
func _strike() -> void:
	lightning_struck.emit()
	if _sun == null or not GameFeel.flashes_allowed():
		return
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sun, "light_energy", _sun_energy * data.lightning_energy, FLASH_RISE)
	_flash_tween.tween_property(_sun, "light_energy", _sun_energy, FLASH_FALL)


static func _first_of(world: Node, type_name: String) -> Node:
	var found: Array[Node] = world.find_children("*", type_name, true, false)
	return found[0] if not found.is_empty() else null
