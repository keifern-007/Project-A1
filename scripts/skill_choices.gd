class_name SkillChoices
extends RefCounted
## The rules for which skills a hero may unlock and put on keys 1-4. SaveManager stores the result.
## A hero's save entry: { "unlocked": [skill id], "hero_keys": [id, id] or [],
## "weapon_keys": { weapon type: [id, id] } }. Empty keys = the defaults.
##
## Keys 1-2: the hero's signature skills (free), plus anything unlocked from their own pool or the
## shared pool, at most 1 shared. Keys 3-4: free, from the weapon's pool: its type's base skills plus
## the skills on that exact weapon, so elemental skills need an elemental weapon.


static func empty_entry() -> Dictionary:
	return { "unlocked": [], "hero_keys": [], "weapon_keys": {} }


## Skill points to unlock it. Weapon skills aren't unlocked with points, so they aren't priced.
static func unlock_cost(skill: SkillData) -> int:
	return Progression.SHARED_SKILL_COST if skill.shared else Progression.HERO_SKILL_COST


static func in_hero_pool(character: CharacterData, skill: SkillData) -> bool:
	return skill.shared or character.skill_pool.has(skill) or character.signature_skills.has(skill)


static func is_unlocked(entry: Dictionary, character: CharacterData, skill: SkillData) -> bool:
	return character.signature_skills.has(skill) or entry["unlocked"].has(str(skill.id))


## Why these two can't go on keys 1-2: &"same", &"locked", &"two_shared". &"" = they can.
static func hero_keys_block(entry: Dictionary, character: CharacterData, first: SkillData, second: SkillData) -> StringName:
	if first == second:
		return &"same"
	if not is_unlocked(entry, character, first) or not is_unlocked(entry, character, second):
		return &"locked"
	if first.shared and second.shared:
		return &"two_shared"
	return &""


## The skills on keys 1-2: the saved choice, or the signature skills.
static func hero_keys(entry: Dictionary, character: CharacterData) -> Array[SkillData]:
	var skills: Array[SkillData] = _skills_from(entry["hero_keys"])
	if skills.size() == 2 and hero_keys_block(entry, character, skills[0], skills[1]) == &"":
		return skills
	return character.signature_skills.duplicate()


## The save key for a weapon's choices. Each type remembers its own, so swapping axes keeps them.
static func weapon_type(weapon: ItemData) -> String:
	return str(weapon.category) if weapon else str(Progression.UNARMED_TYPE)


## What this weapon offers on keys 3-4 (null = unarmed): its own skills first, then its type's base skills.
static func weapon_pool(weapon: ItemData) -> Array[SkillData]:
	var pool: Array[SkillData] = []
	if weapon:
		pool.assign(weapon.skills)
	var type: StringName = StringName(weapon_type(weapon))
	for skill: SkillData in SkillRegistry.all():
		if skill.weapon_types.has(type) and not pool.has(skill):
			pool.append(skill)
	return pool


## The skills chosen for keys 3-4 with this weapon. A choice this weapon can't use (Flame Cleave on
## a plain axe) is replaced from its pool. Nothing chosen = empty: the caller uses its defaults.
static func weapon_keys(entry: Dictionary, weapon: ItemData) -> Array[SkillData]:
	var chosen: Array[SkillData] = []
	var stored: Array = entry["weapon_keys"].get(weapon_type(weapon), [])
	if stored.is_empty():
		return chosen
	var pool: Array[SkillData] = weapon_pool(weapon)
	for skill: SkillData in _skills_from(stored):
		if pool.has(skill):
			chosen.append(skill)
	for skill: SkillData in pool:
		if chosen.size() < 2 and not chosen.has(skill):
			chosen.append(skill)
	return chosen


## Why these two can't go on keys 3-4: &"same", &"not_for_weapon". &"" = they can.
static func weapon_keys_block(weapon: ItemData, first: SkillData, second: SkillData) -> StringName:
	if first == second:
		return &"same"
	var pool: Array[SkillData] = weapon_pool(weapon)
	return &"" if pool.has(first) and pool.has(second) else &"not_for_weapon"


## One hero's saved entry, cleaned: right types, only skills that still exist and that this hero can
## have (skill data can change between versions). Points already spent stay spent.
static func clean_entry(saved: Variant, character: CharacterData) -> Dictionary:
	var entry: Dictionary = empty_entry()
	if not saved is Dictionary:
		return entry
	var data: Dictionary = saved
	for skill: SkillData in _skills_from(data.get("unlocked", [])):
		if in_hero_pool(character, skill) and not entry["unlocked"].has(str(skill.id)):
			entry["unlocked"].append(str(skill.id))
	entry["hero_keys"] = _ids_of(_skills_from(data.get("hero_keys", [])))
	var saved_weapon_keys: Variant = data.get("weapon_keys", {})
	if saved_weapon_keys is Dictionary:
		for type: Variant in saved_weapon_keys:
			entry["weapon_keys"][str(type)] = _ids_of(_skills_from(saved_weapon_keys[type]))
	return entry


static func _skills_from(ids: Variant) -> Array[SkillData]:
	var skills: Array[SkillData] = []
	if ids is Array:
		for id: Variant in ids:
			var skill: SkillData = SkillRegistry.get_by_id(str(id))
			if skill:
				skills.append(skill)
	return skills


static func _ids_of(skills: Array[SkillData]) -> Array:
	var ids: Array = []
	for skill: SkillData in skills:
		ids.append(str(skill.id))
	return ids
