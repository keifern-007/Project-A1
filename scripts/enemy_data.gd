class_name EnemyData
extends Resource
## One enemy type, saved as a .tres in resources/enemies/. Biome variants come in Phase 4.

@export var name_key: String = "" ## Translation key, e.g. "ENEMY_GOBLIN".

@export_group("Stats")
@export var max_health: int = 30
@export var attack_power: int = 8
@export var defense: int = 0
@export var move_speed: float = 3.5
@export_range(0.0, 1.0) var knockback_resistance: float = 0.0 ## 1 = immovable (bosses).

@export_group("Behaviour")
@export var detection_range: float = 10.0 ## Starts chasing when a player gets this close.
@export var attack_range: float = 1.6
@export var attack_windup: float = 0.4 ## Telegraph time before the hit — the player's dodge window.
@export var attack_recovery: float = 0.6 ## Pause after swinging, the player's punish window.

@export_group("Rewards")
@export var xp_reward: int = 5
@export var drops: Array[DropEntry] = []

@export_group("Accessibility")
## Spider-type enemies get an alternate look when arachnophobia mode is on (Phase 6).
@export var is_arachnid: bool = false
