class_name TalentData
extends Resource
## One node in a hero's talent tree, saved as a .tres in resources/talents/<hero>/.
## Bought at the Skill Shrine with the shared skill points. Tier N needs any tier N-1 talent
## of the same hero; talents sharing an exclusive_group are "choose one" (trade-off capstones).
## Any field left at 0 does nothing, so one talent can mix bonuses and penalties.

const COST_PER_TIER: Array[int] = [0, 1, 2, 3] ## Index = tier.

@export var id: StringName = &"" ## Save-file key. Never change it once players have saves.
@export var name_key: String = ""
@export_range(1, 3) var tier: int = 1
@export var exclusive_group: StringName = &"" ## Same non-empty group = only one can be owned.

@export_group("Character") ## Fractions: 0.1 = +10%, -0.2 = -20%.
@export var max_health_percent: float = 0.0
@export var damage_percent: float = 0.0
@export var move_speed_percent: float = 0.0
@export var damage_taken_percent: float = 0.0 ## Negative = tougher.
@export var passive_bonus: float = 0.0 ## 0.5 = the hero's passive is 50% stronger.

@export_group("Skill") ## Tunes one skill (signature, weapon or basic attack).
@export var skill: SkillData
@export var skill_damage_percent: float = 0.0
@export var skill_cooldown_percent: float = 0.0 ## -0.25 = 25% shorter cooldown.


func cost() -> int:
	return COST_PER_TIER[clampi(tier, 1, COST_PER_TIER.size() - 1)]


## One line per effect, e.g. "+10% move speed", "Dash Strike: -25% cooldown". The sign carries
## the meaning (trade-offs read as minus), so it never depends on color.
func effect_lines() -> Array[String]:
	var lines: Array[String] = []
	for entry: Array in [[max_health_percent, "TALENT_MAX_HEALTH"], [damage_percent, "TALENT_DAMAGE"],
			[move_speed_percent, "TALENT_MOVE_SPEED"], [damage_taken_percent, "TALENT_DAMAGE_TAKEN"],
			[passive_bonus, "TALENT_PASSIVE"]]:
		if not is_zero_approx(entry[0]):
			lines.append(TranslationServer.translate(entry[1]) % roundi(entry[0] * 100.0))
	if skill:
		var skill_name: String = TranslationServer.translate(skill.name_key)
		if not is_zero_approx(skill_damage_percent):
			lines.append(TranslationServer.translate("TALENT_SKILL_DAMAGE") % [skill_name, roundi(skill_damage_percent * 100.0)])
		if not is_zero_approx(skill_cooldown_percent):
			lines.append(TranslationServer.translate("TALENT_SKILL_COOLDOWN") % [skill_name, roundi(skill_cooldown_percent * 100.0)])
	return lines


## Everything a set of owned talents adds up to. Percent fields add together;
## skill_damage / skill_cooldown map SkillData -> multiplier.
static func totals(talents: Array[TalentData]) -> Dictionary:
	var sum: Dictionary = {
		"max_health": 0.0, "damage": 0.0, "move_speed": 0.0, "damage_taken": 0.0, "passive": 0.0,
		"skill_damage": {}, "skill_cooldown": {},
	}
	for talent: TalentData in talents:
		sum["max_health"] += talent.max_health_percent
		sum["damage"] += talent.damage_percent
		sum["move_speed"] += talent.move_speed_percent
		sum["damage_taken"] += talent.damage_taken_percent
		sum["passive"] += talent.passive_bonus
		if talent.skill:
			var damage: Dictionary = sum["skill_damage"]
			var cooldown: Dictionary = sum["skill_cooldown"]
			damage[talent.skill] = damage.get(talent.skill, 1.0) + talent.skill_damage_percent
			cooldown[talent.skill] = cooldown.get(talent.skill, 1.0) + talent.skill_cooldown_percent
	return sum
