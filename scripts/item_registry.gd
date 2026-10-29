class_name ItemRegistry
extends RefCounted
## Every ItemData (equipment) in resources/items/, sorted by slot then id.
## Adding a craftable item = dropping a .tres in the folder. (Boosters there are skipped.)

const FOLDER: String = "res://resources/items/"

static var _items: Array[ItemData] = []


static func all() -> Array[ItemData]:
	if _items.is_empty():
		for resource: Resource in ResourceFolder.load_all(FOLDER):
			var item: ItemData = resource as ItemData
			if item:
				_items.append(item)
		_items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
			return a.slot < b.slot if a.slot != b.slot else str(a.id) < str(b.id))
	return _items


static func get_by_id(id: String) -> ItemData:
	for item: ItemData in all():
		if str(item.id) == id:
			return item
	return null
