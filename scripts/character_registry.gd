class_name CharacterRegistry
extends RefCounted
## Every CharacterData in resources/characters/, in select-screen order.

const FOLDER: String = "res://resources/characters/"

static var _characters: Array[CharacterData] = []


static func all() -> Array[CharacterData]:
	if _characters.is_empty():
		for resource: Resource in ResourceFolder.load_all(FOLDER):
			var character: CharacterData = resource as CharacterData
			if character:
				_characters.append(character)
		_characters.sort_custom(func(a: CharacterData, b: CharacterData) -> bool: return a.sort_order < b.sort_order)
	return _characters


## The character with this id, or the first one if it doesn't exist (new or old saves).
static func get_by_id(id: String) -> CharacterData:
	for character: CharacterData in all():
		if str(character.id) == id:
			return character
	return all()[0] if not all().is_empty() else null
