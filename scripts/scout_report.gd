class_name ScoutReport
extends RefCounted
## The Mission Board's text about a boss: what hurts it, what heals it, its hazard and counter, and
## whether this hero's skills or Inventory are ready. It's what makes the boss's punishments fair.


static func text(objective: ObjectiveData, character: CharacterData) -> String:
	var boss: EnemyData = objective.scout_boss
	if boss == null:
		return ""
	var lines: Array[String] = [_t("UI_SCOUT_TITLE")]
	var weak: Array[String] = []
	var resist: Array[String] = []
	var immune: Array[String] = []
	var heals: Array[String] = []
	for element: Element.Type in [Element.Type.FIRE, Element.Type.ICE, Element.Type.POISON]:
		var multiplier: float = boss.element_multiplier(element)
		var element_name: String = _t(Element.name_key(element))
		if boss.absorbs == element:
			heals.append(element_name)
		elif multiplier > 1.0:
			weak.append(element_name)
		elif multiplier == 0.0:
			immune.append(element_name)
		elif multiplier < 1.0:
			resist.append(element_name)
	if not weak.is_empty():
		lines.append(_t("UI_SCOUT_WEAK_STAGGER" if boss.stagger_threshold > 0.0 else "UI_SCOUT_WEAK") % ", ".join(weak))
	if not heals.is_empty():
		lines.append(_t("UI_SCOUT_HEALS") % ", ".join(heals))
	if not resist.is_empty():
		lines.append(_t("UI_SCOUT_RESISTS") % ", ".join(resist))
	if not immune.is_empty():
		lines.append(_t("UI_SCOUT_IMMUNE") % ", ".join(immune))
	var warning: String = _skill_warning(boss, character)
	if warning != "":
		lines.append(warning)
	if objective.hazard:
		lines.append(_hazard_line(objective.hazard))
	return "\n".join(lines)


## Names this hero's skills that would heal the boss, so a player can plan around them.
static func _skill_warning(boss: EnemyData, character: CharacterData) -> String:
	if boss.absorbs == Element.Type.PHYSICAL or character == null:
		return ""
	var skills: Array[SkillData] = character.signature_skills.duplicate()
	var weapon: ItemData = SaveManager.get_equipped(ItemData.Slot.MAIN_HAND, str(character.id))
	if weapon:
		skills.append_array(weapon.skills)
	var names: Array[String] = []
	for skill: SkillData in skills:
		if skill.element == boss.absorbs:
			names.append(_t(skill.name_key))
	return _t("UI_SCOUT_SKILL_WARNING") % ", ".join(names) if not names.is_empty() else ""


static func _hazard_line(hazard: HazardData) -> String:
	var line: String = _t("UI_SCOUT_HAZARD") % [_t(hazard.name_key), _t(hazard.effect_key)]
	var counter: ItemData = ItemRegistry.get_by_id(hazard.counter_item_id)
	if counter == null:
		return line
	var carried: int = 0
	for entry: Dictionary in SaveManager.get_pack():
		if entry.get("id", "") == hazard.counter_item_id:
			carried += int(entry["count"])
	return line + "\n" + _t("UI_SCOUT_COUNTER") % [_t(counter.name_key), carried]


static func _t(key: String) -> String:
	return str(TranslationServer.translate(key))
