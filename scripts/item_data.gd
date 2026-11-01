class_name ItemData
extends Resource
## A piece of equipment, crafted at the Forge from materials. Saved as a .tres in resources/items/.
## Stat bonuses can be negative on purpose: trade-offs are a design pillar
## (pick a strength, accept a weakness).

## Albion-style loadout. Hands: two-handed weapons take both; off-hand items (shields, books)
## only go off-hand; one-handed main-hand weapons may also go off-hand (dual-wield).
enum Slot { MAIN_HAND, OFF_HAND, HELMET, CHEST, WAIST, BOOTS, TRINKET, CONSUMABLE }
enum Style { ANY, PHYSICAL, MAGIC }

@export var id: StringName = &"" ## Save-file key. Never change it once players have saves.
@export var name_key: String = ""
@export var description_key: String = ""
@export var slot: Slot = Slot.MAIN_HAND
@export var two_handed: bool = false ## Main-hand weapons only: also occupies the off hand.
@export var tier: int = 1 ## T1, T2... Higher tiers will need higher crafting / mastery levels.
## Which crafting and mastery track this belongs to, e.g. &"axe", &"shield", &"leaf_armor".
@export var category: StringName = &""
## Forge filter: who this is meant for. Only a recommendation, every hero can still use it.
@export var style: Style = Style.ANY
@export var color: Color = Color.WHITE ## Placeholder look until real art exists.
## Main-hand weapons: the skills it grants on keys 3-4 (up to 2). Empty = the unarmed default.
@export var skills: Array[SkillData] = []
## Main-hand weapons: scales the wind-up of basic swings and this weapon's skills. Bigger = slower.
@export var windup_multiplier: float = 1.0

@export_group("Stats")
@export var max_health: int = 0
@export var attack_power: int = 0
@export var defense: int = 0

@export_group("Consumable")
## CONSUMABLE slot only: what drinking/using it does. One copy is used up each time.
@export var use_effect: BoosterData
@export var use_cooldown: float = 10.0 ## Seconds before the next one can be used.

@export_group("Recipe")
@export var cost: Array[MaterialCost] = []


## Translation key for a slot's name, e.g. "SLOT_MAIN_HAND".
static func slot_key(for_slot: Slot) -> String:
	return "SLOT_" + Slot.keys()[for_slot]


## Translation key for a Forge set's name (all the items of one slot), e.g. "UI_SET_MAIN_HAND".
static func set_key(for_slot: Slot) -> String:
	return "UI_SET_" + Slot.keys()[for_slot]


## Translation key for a style's name, e.g. "UI_STYLE_MAGIC".
static func style_key(for_style: Style) -> String:
	return "UI_STYLE_" + Style.keys()[for_style]


func can_go_in(target: Slot) -> bool:
	if target == slot:
		return true
	# Dual-wield: a one-handed weapon can be held in the off hand too.
	return target == Slot.OFF_HAND and slot == Slot.MAIN_HAND and not two_handed


## "Heavy weapon: wind-up x1.6" for the Forge and Gear Rack; "" if this isn't a weapon.
func weight_text() -> String:
	if slot != Slot.MAIN_HAND:
		return ""
	var weight_key: String = "UI_WEIGHT_MEDIUM"
	if windup_multiplier > 1.0:
		weight_key = "UI_WEIGHT_HEAVY"
	elif windup_multiplier < 1.0:
		weight_key = "UI_WEIGHT_LIGHT"
	return TranslationServer.translate("UI_WEAPON_WEIGHT") % [TranslationServer.translate(weight_key), windup_multiplier]


## "Skills: Cleave, Hatchet Throw" for the Forge and Gear Rack; "" if it grants none.
func skills_text() -> String:
	if skills.is_empty():
		return ""
	var names: Array[String] = []
	for skill: SkillData in skills:
		names.append(skill.display_name())
	return TranslationServer.translate("UI_WEAPON_SKILLS") % ", ".join(names)
