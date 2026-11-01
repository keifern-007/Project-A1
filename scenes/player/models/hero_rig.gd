class_name HeroRig
extends Node3D
## A hero's jointed model: pivots named %ArmR, %ThighL and so on, posed every frame in code.
## This script wears the gear; HeroAnimator moves the joints. Also used for the 3D previews (no Player).
## Item models live in scenes/items/<item id>.tscn and sit on a slot pivot. See ItemData.model().

enum Style { FIGHTER, TANK, CASTER } ## How they stand and how their idle flourish looks.

@export var style: Style = Style.FIGHTER

var has_off_hand: bool = false
var has_main_hand: bool = false
var two_handed: bool = false
var weapon_kind: StringName = &"" ## The main hand's category: &"axe", &"dagger", &"wand"... &"" = fists.
var trail_color: Color = Color(0.95, 0.95, 1.0)

var _worn: Array[Node3D] = []


## Shows a loadout on the model. Items without a model are skipped.
func wear(items: Dictionary) -> void:
	for node: Node3D in _worn:
		node.queue_free()
	_worn.clear()
	has_main_hand = false
	has_off_hand = false
	two_handed = false
	weapon_kind = &""
	trail_color = Color(0.95, 0.95, 1.0)
	var hat: Node3D = get_node_or_null("%HatGroup")
	if hat:
		hat.visible = not items.has(ItemData.Slot.HELMET)
	for slot: int in items:
		_wear_item(items[slot], slot)


## The saved loadout of this character.
func wear_loadout(character_id: String) -> void:
	var items: Dictionary = {}
	for slot: int in ItemData.Slot.values():
		var item: ItemData = SaveManager.get_equipped(slot, character_id)
		if item:
			items[slot] = item
	wear(items)


func _wear_item(item: ItemData, slot: int) -> void:
	match slot:
		ItemData.Slot.MAIN_HAND:
			has_main_hand = true
			two_handed = item.two_handed
			weapon_kind = item.category
			trail_color = item.color
			_attach(item, "%HandR")
		ItemData.Slot.OFF_HAND:
			has_off_hand = true
			_attach(item, "%HandL")
		ItemData.Slot.HELMET:
			_attach(item, "%HeadSlot")
		ItemData.Slot.CHEST:
			_attach(item, "%ChestSlot")
		ItemData.Slot.WAIST, ItemData.Slot.CONSUMABLE:
			_attach(item, "%WaistSlot")
		ItemData.Slot.BOOTS:
			_attach(item, "%FootL")
			_attach(item, "%FootR")
		ItemData.Slot.TRINKET:
			_attach(item, "%NeckSlot")


func _attach(item: ItemData, slot_path: String) -> void:
	var scene: PackedScene = item.model()
	if scene == null:
		return
	var model: Node3D = scene.instantiate()
	get_node(slot_path).add_child(model)
	_worn.append(model)


## Half see-through while invulnerable (dodging). Reaches every part of the model.
func set_ghosted(on: bool) -> void:
	_ghost(self, 0.5 if on else 0.0)


func _ghost(node: Node, amount: float) -> void:
	for child: Node in node.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).transparency = amount
		_ghost(child, amount)
