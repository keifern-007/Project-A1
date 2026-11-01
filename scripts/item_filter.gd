class_name ItemFilter
extends RefCounted
## What the Forge is currently showing: one set (slot), one material, one style. Defaults show everything.

const ALL_SETS: int = -1

var set_slot: int = ALL_SETS ## An ItemData.Slot, or ALL_SETS.
var material_id: StringName = &"" ## Only recipes using this material. Empty = any.
var style: ItemData.Style = ItemData.Style.ANY ## ANY = no filter. 'Any build' items always pass.


func matches(item: ItemData) -> bool:
	if set_slot != ALL_SETS and item.slot != set_slot:
		return false
	if style != ItemData.Style.ANY and item.style != ItemData.Style.ANY and item.style != style:
		return false
	if material_id == &"":
		return true
	for cost: MaterialCost in item.cost:
		if cost.material.id == material_id:
			return true
	return false


## The materials used by the recipes of the current set, sorted by name.
func materials_in_set(items: Array[ItemData]) -> Array[MaterialData]:
	var found: Array[MaterialData] = []
	for item: ItemData in items:
		if set_slot != ALL_SETS and item.slot != set_slot:
			continue
		for cost: MaterialCost in item.cost:
			if not found.has(cost.material):
				found.append(cost.material)
	found.sort_custom(func(a: MaterialData, b: MaterialData) -> bool:
		return str(TranslationServer.translate(a.name_key)) < str(TranslationServer.translate(b.name_key)))
	return found
