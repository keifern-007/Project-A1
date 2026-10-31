class_name SpawnEntry
extends Resource
## One line of a map's enemy pool (MapData.enemy_pool): which enemy, how common, from which wave.
## Specials join in later waves, so players meet one new thing at a time.

@export var enemy_scene: PackedScene
@export var weight: float = 1.0 ## Relative chance among the entries allowed this wave.
@export var from_wave: int = 1 ## Can spawn from this wave on.
## Spawned together at one point (Skitterlings come in 6s). A pack uses one slot of the wave.
@export var pack_size: int = 1
