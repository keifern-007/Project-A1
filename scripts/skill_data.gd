class_name SkillData
extends Resource
## One skill, saved as a .tres in resources/skills/. New skill = new .tres + effect scene.
## Physical skills spend stamina, magic skills spend mana. Basic attacks (Magic Bolt) are free.

enum Kind { PHYSICAL, MAGIC }

@export var name_key: String = "" ## Translation key, e.g. "SKILL_GROUND_SLAM".
@export var cooldown: float = 5.0
@export var damage_multiplier: float = 1.0 ## × the caster's attack_power.
@export var kind: Kind = Kind.PHYSICAL
@export var cost: float = 0.0 ## Stamina (physical) or mana (magic) spent per cast.
## Seconds of casting before it fires (big magic only). You move slowly; dodging cancels and refunds.
@export var cast_time: float = 0.0
## Spawned when the skill is cast. Its root script must extend SkillEffect.
@export var effect_scene: PackedScene
