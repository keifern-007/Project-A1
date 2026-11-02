class_name SkillRegistry
extends RefCounted
## Every SkillData in resources/skills/, sorted by id, so the save file can name skills by id.

const FOLDER: String = "res://resources/skills/"

static var _skills: Array[SkillData] = []


static func all() -> Array[SkillData]:
	if _skills.is_empty():
		for resource: Resource in ResourceFolder.load_all(FOLDER):
			var skill: SkillData = resource as SkillData
			if skill:
				_skills.append(skill)
		_skills.sort_custom(func(a: SkillData, b: SkillData) -> bool: return str(a.id) < str(b.id))
	return _skills


static func get_by_id(id: String) -> SkillData:
	for skill: SkillData in all():
		if str(skill.id) == id:
			return skill
	return null
