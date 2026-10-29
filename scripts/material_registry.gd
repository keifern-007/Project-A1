class_name MaterialRegistry
extends RefCounted
## Finds every MaterialData in resources/materials/ by its id, so saved ids ("goblin_ear")
## can be turned back into names and colors. Adding a material = dropping a .tres in the folder.

const FOLDER: String = "res://resources/materials/"

static var _by_id: Dictionary = {}


static func get_by_id(id: String) -> MaterialData:
	_ensure_loaded()
	return _by_id.get(id)


static func all() -> Array[MaterialData]:
	_ensure_loaded()
	var materials: Array[MaterialData] = []
	materials.assign(_by_id.values())
	return materials


static func _ensure_loaded() -> void:
	if _by_id.is_empty():
		for resource: Resource in ResourceFolder.load_all(FOLDER):
			var material: MaterialData = resource as MaterialData
			if material:
				_by_id[str(material.id)] = material
