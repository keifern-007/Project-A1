class_name ForgeFilters
extends VBoxContainer
## The Forge's filter controls: one tab per set, a material dropdown and a Mage/Physical dropdown.
## Keeps the choices in `filter` and emits `changed`; the panel decides what to show.

signal changed

var filter: ItemFilter = ItemFilter.new()

var _tabs: Dictionary = {} # ItemData.Slot or ItemFilter.ALL_SETS -> Button

@onready var set_tabs: HFlowContainer = %SetTabs
@onready var material_filter: OptionButton = %MaterialFilter
@onready var style_filter: OptionButton = %StyleFilter


func _ready() -> void:
	_build_tabs()
	for style: int in [ItemData.Style.ANY, ItemData.Style.PHYSICAL, ItemData.Style.MAGIC]:
		var key: String = "UI_FILTER_ALL_STYLES" if style == ItemData.Style.ANY else ItemData.style_key(style)
		style_filter.add_item(tr(key), style)
	style_filter.item_selected.connect(_on_style_selected)
	material_filter.item_selected.connect(_on_material_selected)
	refresh_materials()


## The dropdown lists only the current set's materials, with how many you own.
## If the chosen material isn't used in this set, it goes back to 'All materials'.
func refresh_materials() -> void:
	material_filter.clear()
	material_filter.add_item(tr("UI_FILTER_ALL_MATERIALS"))
	material_filter.set_item_metadata(0, &"")
	var chosen: int = 0
	for material: MaterialData in filter.materials_in_set(ItemRegistry.all()):
		material_filter.add_item(tr("UI_FILTER_MATERIAL_ROW") % [tr(material.name_key), SaveManager.get_material_count(str(material.id))])
		var index: int = material_filter.item_count - 1
		material_filter.set_item_metadata(index, material.id)
		if material.id == filter.material_id:
			chosen = index
	material_filter.select(chosen)
	filter.material_id = material_filter.get_item_metadata(chosen)


func _on_style_selected(index: int) -> void:
	filter.style = style_filter.get_item_id(index) as ItemData.Style
	changed.emit()


func _on_material_selected(index: int) -> void:
	filter.material_id = material_filter.get_item_metadata(index)
	changed.emit()


## One tab per set, plus 'All'. Sets nothing can be crafted for get no tab.
func _build_tabs() -> void:
	var group: ButtonGroup = ButtonGroup.new()
	_add_tab(ItemFilter.ALL_SETS, "UI_SET_ALL", group)
	for slot: int in ItemData.Slot.values():
		if ItemRegistry.all().any(func(item: ItemData) -> bool: return item.slot == slot):
			_add_tab(slot, ItemData.set_key(slot), group)
	_tabs[ItemFilter.ALL_SETS].button_pressed = true
	_refresh_tabs()


func _add_tab(slot: int, key: String, group: ButtonGroup) -> void:
	var tab: Button = Button.new()
	tab.toggle_mode = true
	tab.button_group = group
	tab.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	tab.set_meta("key", key)
	tab.custom_minimum_size = Vector2(0, 36)
	tab.add_theme_font_size_override("font_size", 17)
	tab.pressed.connect(show_set.bind(slot))
	set_tabs.add_child(tab)
	_tabs[slot] = tab


## Switches to one set (an ItemData.Slot) or ItemFilter.ALL_SETS.
func show_set(slot: int) -> void:
	filter.set_slot = slot
	_refresh_tabs()
	refresh_materials()
	changed.emit()


# Selection gets a marker, not just a darker shade (never color alone).
func _refresh_tabs() -> void:
	for slot: int in _tabs:
		var tab: Button = _tabs[slot]
		tab.text = ("» " if slot == filter.set_slot else "") + tr(tab.get_meta("key"))
