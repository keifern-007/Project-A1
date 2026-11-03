class_name MapData
extends Resource
## One playable map, saved as a .tres in resources/maps/. Its look and weather live in the scene;
## the mission's mood (storm, bright) is added on top by MissionMood.

## Where the Mission Board lists it: Rogue = short roguelike missions, Expedition = the big maps.
enum Category { ROGUE, EXPEDITION }

@export var name_key: String = "" ## Translation key, e.g. "MAP_GREYBOX".
@export var description_key: String = ""
@export var required_rank: int = 1 ## Locked on the Mission Board until this Rank.
@export var biome: BiomeData ## Empty = enemies stay their base type.
@export var category: Category = Category.ROGUE
## True = only objectives made for this map (only_on_map) are offered on it, e.g. a big map's Expedition.
@export var own_objectives_only: bool = false
## Big maps: the weather found in some of its areas (WeatherZones in the scene). Only for the Mission Board's text.
@export var zone_weather: Array[WeatherData] = []
## Which enemies spawn here, how often and from which wave. Empty = the map's WaveSpawner list.
@export var enemy_pool: Array[SpawnEntry] = []
## The map scene: floor/walls, camera, player, WaveSpawner, and markers
## ("gather_points", "boss_spawns") for the objectives it supports.
@export var scene: PackedScene
