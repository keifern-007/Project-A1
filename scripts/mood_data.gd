class_name MoodData
extends Resource
## A mission's mood, saved as a .tres in resources/moods/ and set on an ObjectiveData.
## Applied on top of whatever map is loaded (MissionMood), so every map can be bright or stormy.
## Multipliers keep each map's own character: a stormy desert is still warmer than a stormy pass.

@export_group("Sky")
@export var sky_top_color: Color = Color(0.2, 0.22, 0.28)
@export var sky_horizon_color: Color = Color(0.4, 0.42, 0.47)
@export_range(0.0, 1.0) var sky_blend: float = 0.0 ## 0 = keep the map's sky, 1 = these colors.

@export_group("Light")
@export var sun_energy_multiplier: float = 1.0
@export var sun_color: Color = Color.WHITE
@export_range(0.0, 1.0) var sun_color_blend: float = 0.0
@export var ambient_energy_multiplier: float = 1.0
@export var saturation_multiplier: float = 1.0

@export_group("Fog")
@export var fog_color: Color = Color(0.4, 0.42, 0.48)
@export_range(0.0, 1.0) var fog_blend: float = 0.0
@export var fog_density_min: float = 0.0 ## Fog is at least this thick. 0 = keep the map's fog.

@export_group("Weather")
## Added to the map (e.g. rain). Scenes in scenes/vfx/weather/.
@export var weather: PackedScene
## Use the biome's own storm (blizzard, sandstorm) instead of `weather` when it has one.
@export var use_biome_storm_weather: bool = false

@export_group("Lightning")
## Seconds between strikes, picked between min and max. 0 = no lightning.
@export var lightning_interval_min: float = 0.0
@export var lightning_interval_max: float = 0.0
@export var lightning_energy: float = 4.0 ## Sun brightness × this for a split second.
