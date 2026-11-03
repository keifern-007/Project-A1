class_name SiteEntry
extends Resource
## One kind of site a SiteScatter can place on a big map (a goblin camp, a herb patch...).

@export var scene: PackedScene
@export var weight: float = 1.0 ## Higher = picked more often.
@export var max_count: int = 4 ## At most this many on one map.
## Slot tags this site can go in ("land", "river", "ridge"). Empty = anywhere.
@export var allowed_tags: PackedStringArray = PackedStringArray(["land"])


func fits(slot_tags: PackedStringArray) -> bool:
	if allowed_tags.is_empty():
		return true
	for tag: String in slot_tags:
		if allowed_tags.has(tag):
			return true
	return false
