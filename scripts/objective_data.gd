class_name ObjectiveData
extends Resource
## One mission objective, saved as a .tres in resources/objectives/.

enum Type { HORDE, BOSS, GATHER }

@export var name_key: String = "" ## Translation key shown on the HUD, e.g. "OBJ_HORDE".
@export var description_key: String = "" ## Shown on mission select.
@export var type: Type = Type.HORDE
@export var required_rank: int = 1 ## Locked on the Mission Board until this Rank.
## Re-lights the map: storm for bosses, bright for gathering. Empty = the map as it is.
@export var mood: MoodData

@export_group("Horde")
@export var waves_to_survive: int = 5

@export_group("Enemy Waves") ## Horde, Gather, and Boss (before the boss appears).
@export var first_wave_size: int = 3
@export var wave_size_growth: int = 2 ## Extra enemies per wave.
@export var health_growth_per_wave: float = 0.15 ## +15% enemy HP each wave after the first.

@export_group("Gather")
@export var gather_material: MaterialData
@export var gather_amount: int = 10
## Spawned at every Marker3D in group "gather_points" on the map.
@export var gather_node_scene: PackedScene

@export_group("Boss")
@export var boss_scene: PackedScene ## Spawned at the map's "boss_spawns" marker.
@export var kills_before_boss: int = 8 ## 0 = boss appears immediately.
@export var boss_drop: MaterialData ## Boss-exclusive reward.
@export var boss_drop_amount: int = 1
