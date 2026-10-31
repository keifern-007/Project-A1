class_name CharacterComponent
extends Node
## Which character this body is. Writes the character's base stats into StatsComponent on spawn.
## Must come right after StatsComponent in the scene, so Health and Equipment build on top of it.
## The owner reads `data` for everything that isn't a stat (speed, dodge, look).

## Leave empty to use the character chosen in the save (Phase 5: each peer's own choice).
@export var data: CharacterData
@export var stats: StatsComponent
## Keys 3-4 when the main hand is empty or the weapon grants no skills.
@export var unarmed_skills: Array[SkillData] = []
@export var unarmed_windup_multiplier: float = 0.8 ## Fists are lighter than any axe.


func _ready() -> void:
	if data == null:
		data = SaveManager.get_character()
	stats.max_health = data.max_health
	stats.attack_power = data.attack_power
	stats.defense = data.defense


## Keys 1-2: the character's signature skills. Keys 3-4: the main-hand weapon's skills
## (from this character's own loadout), else the unarmed ones.
func skill_loadout() -> Array[SkillData]:
	var loadout: Array[SkillData] = data.signature_skills.duplicate()
	loadout.append_array(weapon_skills())
	return loadout


func weapon_skills() -> Array[SkillData]:
	var weapon: ItemData = _main_hand()
	return weapon.skills if weapon and not weapon.skills.is_empty() else unarmed_skills


## How much the main hand slows basic swings and weapon skills. Signature skills don't care.
func weapon_windup_multiplier() -> float:
	var weapon: ItemData = _main_hand()
	return weapon.windup_multiplier if weapon else unarmed_windup_multiplier


func _main_hand() -> ItemData:
	return SaveManager.get_equipped(ItemData.Slot.MAIN_HAND, str(data.id))
