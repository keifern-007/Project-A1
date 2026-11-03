class_name ObjectiveData
extends Resource
## One mission objective, saved as a .tres in resources/objectives/.

enum Type { HORDE, BOSS, GATHER, TUTORIAL, ENDLESS_SURVIVAL, ENDLESS_BOSS, CLASSIC, EXPEDITION, HUNT }

@export var name_key: String = "" ## Translation key shown on the HUD, e.g. "OBJ_HORDE".
@export var description_key: String = "" ## Shown on mission select.
@export var type: Type = Type.HORDE
@export var required_rank: int = 1 ## Locked on the Mission Board until this Rank.
## Re-lights the map: storm for bosses, bright for gathering. Empty = the map as it is.
@export var mood: MoodData
## Set = the Mission Board only lists this objective on that map. Empty = every map.
@export var only_on_map: MapData
## Materials and XP are multiplied by this when the mission is won (an Expedition's bonus). 1 = none.
@export var victory_reward_multiplier: float = 1.0
## True = the map biome's weather (BiomeData.weather: cold on snow, heat on desert) lasts the whole mission.
## Big maps don't use it: their weather is in WeatherZones.
@export var biome_weather: bool = false

@export_group("Coins") ## See Market. Challenge and Expedition bonuses multiply these too.
@export var coin_reward: int = 0 ## Paid when the mission is won.
## Paid however it ends, per wave reached (Endless Survival) or boss beaten (Endless Boss, Classic).
@export var coins_per_progress: int = 0

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
@export var scout_boss: EnemyData ## What the Mission Board's scouting report describes. Empty = no report.
@export var hazard: HazardData ## Lasting danger once the boss appears. Empty = none.

@export_group("Expedition") ## Big maps.
@export var sites_to_clear: int = 0 ## Sites to finish to win. 0 = every site on the map.

@export_group("Game Mode") ## Endless Boss and Classic: a run made of several steps. See ModeRun.
@export var boss_sequence: Array[ObjectiveData] = [] ## In order. Each boss's only_on_map is where it's fought.
@export var stage_objective: ObjectiveData ## The survival stages before each boss.
@export var stages_per_boss: int = 0
@export var boss_health_growth: float = 0.0 ## +25% boss HP for every boss already beaten this run.


## Never won, only ended: rewards count in full however it ends.
func is_endless() -> bool:
	return type == Type.ENDLESS_SURVIVAL or type == Type.ENDLESS_BOSS


## Plays through several maps and objectives; the map picked on the board isn't used.
func is_multi_step() -> bool:
	return type == Type.ENDLESS_BOSS or type == Type.CLASSIC


func available_on(map: MapData) -> bool:
	if map and map.own_objectives_only:
		return only_on_map == map
	return only_on_map == null or only_on_map == map
