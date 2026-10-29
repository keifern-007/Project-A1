class_name TalentComponent
extends Node
## Applies the hero's learned talents on spawn, on top of base stats and gear: max HP %,
## damage %, damage taken %, and per-skill damage/cooldown. Move speed and the passive bonus
## are read from here by the Player and PassiveComponent.
## Must come after EquipmentComponent in the scene (it scales the final max HP).

const DAMAGE_SOURCE: StringName = &"talents"

@export var character: CharacterComponent
@export var stats: StatsComponent
@export var health: HealthComponent
@export var hurtbox: HurtboxComponent
@export var skill_caster: SkillCasterComponent

var totals: Dictionary = TalentData.totals([])


func _ready() -> void:
	if character.data == null:
		return
	totals = TalentData.totals(SaveManager.owned_talents(character.data))
	stats.max_health = maxi(roundi(stats.max_health * (1.0 + totals["max_health"])), 1)
	health.set_max_health(stats.max_health)
	stats.set_damage_modifier(DAMAGE_SOURCE, 1.0 + totals["damage"])
	hurtbox.damage_taken_multiplier *= maxf(1.0 + totals["damage_taken"], 0.05)
	skill_caster.skill_damage_mods = totals["skill_damage"]
	skill_caster.skill_cooldown_mods = totals["skill_cooldown"]


func move_speed_multiplier() -> float:
	return maxf(1.0 + totals["move_speed"], 0.2)


## 0.5 = the passive's main number is 50% stronger.
func passive_bonus() -> float:
	return totals["passive"]
