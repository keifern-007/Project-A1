class_name CharacterData
extends Resource
## A playable character, saved as a .tres in resources/characters/. Adding a character =
## adding a .tres. Base stats are the trade-off: every character is strong somewhere and weak elsewhere.
## Skills: 2 signature skills here (keys 1-2); the main-hand weapon adds 2 more (keys 3-4).

@export var id: StringName = &"" ## Save-file key. Never change it once players have saves.
@export var name_key: String = ""
@export var role_key: String = "" ## "Fast DPS", "Defender"...
@export var description_key: String = "" ## Playstyle, strengths and weaknesses in words.
@export var sort_order: int = 0 ## Left-to-right on the select screen.
@export var passive: PassiveData ## Always on. Run by the player's PassiveComponent.
@export var signature_skills: Array[SkillData] = [] ## Keys 1-2.
## Empty = melee swing. Set (e.g. Magic Bolt) = the attack button casts this skill instead.
@export var basic_attack: SkillData
## This hero's talent tree (bought at the Skill Shrine). See TalentData.
@export var talents: Array[TalentData] = []

@export_group("Base Stats")
@export var max_health: int = 100
@export var attack_power: int = 10
@export var defense: int = 0
@export var move_speed: float = 6.0
@export var dodge_cooldown: float = 0.6
@export var max_stamina: float = 100.0 ## Spent by physical skills.
@export var stamina_regen: float = 15.0 ## Per second.
@export var max_mana: float = 40.0 ## Spent by magic skills.
@export var mana_regen: float = 2.0 ## Per second: slow on purpose, kills are the main source.
@export var mana_per_kill: float = 6.0

@export_group("Look") ## Placeholder until real models: a tint plus a different silhouette.
@export var color: Color = Color(0.85, 0.45, 0.2)
@export var body_scale: Vector3 = Vector3.ONE
