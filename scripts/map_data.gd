class_name MapData
extends Resource
## One playable map, saved as a .tres in resources/maps/. Mood and weather come in Phase 4.

@export var name_key: String = "" ## Translation key, e.g. "MAP_GREYBOX".
@export var description_key: String = ""
@export var required_rank: int = 1 ## Locked on the Mission Board until this Rank.
@export var biome: BiomeData ## Empty = enemies stay their base type.
## The map scene: floor/walls, camera, player, WaveSpawner, and markers
## ("gather_points", "boss_spawns") for the objectives it supports.
@export var scene: PackedScene
