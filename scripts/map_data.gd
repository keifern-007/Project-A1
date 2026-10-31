class_name MapData
extends Resource
## One playable map, saved as a .tres in resources/maps/. Its look and weather live in the scene;
## the mission's mood (storm, bright) is added on top by MissionMood.

@export var name_key: String = "" ## Translation key, e.g. "MAP_GREYBOX".
@export var description_key: String = ""
@export var required_rank: int = 1 ## Locked on the Mission Board until this Rank.
@export var biome: BiomeData ## Empty = enemies stay their base type.
## Which enemies spawn here, how often and from which wave. Empty = the map's WaveSpawner list.
@export var enemy_pool: Array[SpawnEntry] = []
## The map scene: floor/walls, camera, player, WaveSpawner, and markers
## ("gather_points", "boss_spawns") for the objectives it supports.
@export var scene: PackedScene
