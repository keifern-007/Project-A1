class_name SkillData
extends Resource
## One skill, saved as a .tres in resources/skills/. New skill = new .tres + effect scene.
## Physical skills spend stamina, magic skills spend mana. Basic attacks (Magic Bolt) ignore `cost`:
## they spend the character's attack_stamina_cost instead (paid by the Player).
## Hero signature skills (keys 1-2) are always MAGIC; weapon skills (keys 3-4) depend on the weapon.

enum Kind { PHYSICAL, MAGIC }

@export var id: StringName = &"" ## Save-file key. Never change it once players have saves.
@export var name_key: String = "" ## Translation key, e.g. "SKILL_GROUND_SLAM".
@export var shared: bool = false ## In the pool every hero can pick from on keys 1-2.
## Weapon types offering this as a base skill on keys 3-4, e.g. &"axe". Leave elemental skills empty:
## they come only from the weapons listing them in ItemData.skills.
@export var weapon_types: Array[StringName] = []
## An elemental version of another skill: talents that tune that skill also tune this one.
@export var base_skill: SkillData
@export var breaks_guards: bool = false ## Knocks shields aside whatever the weapon (heavy weapons always do).
@export var cooldown: float = 5.0
@export var damage_multiplier: float = 1.0 ## × the caster's attack_power.
@export var kind: Kind = Kind.PHYSICAL
@export var element: Element.Type = Element.Type.PHYSICAL ## Applies its status on hit; enemies can be weak to it.
@export var cost: float = 0.0 ## Stamina (physical) or mana (magic) spent per cast.
## Wind-up seconds before it fires. You move slowly; dodging cancels and refunds.
@export var cast_time: float = 0.0
## Seconds locked in after it fires: no dodging, no other attacks, barely any walking.
@export var commit_time: float = 0.0
## Spawned when the skill is cast. Its root script must extend SkillEffect.
@export var effect_scene: PackedScene
## How the hero moves when using it: slash, overhead, slam, punch, stab, lunge, cast, raise, guard, spin.
## Empty = decided by the weapon (physical) or a casting pose (magic).
@export var anim: StringName = &""


## Translation key for what it does, e.g. "SKILL_GROUND_SLAM_DESC". Shown at the Skill Shrine.
func description_key() -> String:
	return name_key + "_DESC"


## "Whirlwind (^ Fire)" for menus; physical skills show just their name.
func display_name() -> String:
	var skill_name: String = TranslationServer.translate(name_key)
	if element == Element.Type.PHYSICAL:
		return skill_name
	return "%s (%s)" % [skill_name, TranslationServer.translate(Element.name_key(element))]
