extends Control
## The camp's Gear Rack, Albion-style: a paper doll of 8 slots arranged around the body,
## the gear you own for the selected slot on the right (press to equip, press again to
## unequip), and total stats at the bottom. Hand rules live in SaveManager.equip().

signal closed

## Paper-doll layout: [slot, column, row]. Empty grid cells stay blank.
const DOLL: Array = [
	[ItemData.Slot.TRINKET, 0, 0], [ItemData.Slot.HELMET, 1, 0], [ItemData.Slot.CONSUMABLE, 2, 0],
	[ItemData.Slot.MAIN_HAND, 0, 1], [ItemData.Slot.CHEST, 1, 1], [ItemData.Slot.OFF_HAND, 2, 1],
	[ItemData.Slot.WAIST, 1, 2],
	[ItemData.Slot.BOOTS, 1, 3],
]
const DOLL_COLUMNS: int = 3
const DOLL_ROWS: int = 4
const GOOD_COLOR: String = "#9be37a"
const BAD_COLOR: String = "#f08a7a"

var _slot: ItemData.Slot = ItemData.Slot.MAIN_HAND
var _slot_buttons: Dictionary = {} # Slot -> Button

@onready var hero_preview: ModelPreview = %HeroPreview
@onready var doll_grid: GridContainer = %DollGrid
@onready var title_label: Label = %Title
@onready var items_header: Label = %ItemsHeader
@onready var item_list: VBoxContainer = %ItemList
@onready var totals_label: RichTextLabel = %TotalsLabel
@onready var back_button: Button = %BackButton


func _ready() -> void:
	title_label.text = tr("UI_LOADOUT_OF") % tr(SaveManager.get_character().name_key)
	_build_doll()
	back_button.pressed.connect(closed.emit)
	(_slot_buttons[_slot] as Button).grab_focus()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _build_doll() -> void:
	doll_grid.columns = DOLL_COLUMNS
	var cells: Dictionary = {} # Vector2i -> Slot
	for entry: Array in DOLL:
		cells[Vector2i(entry[1], entry[2])] = entry[0]
	for row: int in DOLL_ROWS:
		for column: int in DOLL_COLUMNS:
			var cell: Vector2i = Vector2i(column, row)
			if not cells.has(cell):
				var spacer: Control = Control.new()
				spacer.custom_minimum_size = Vector2(170, 64)
				doll_grid.add_child(spacer)
				continue
			var slot: ItemData.Slot = cells[cell]
			var button: Button = _make_button(Vector2(170, 64))
			button.pressed.connect(_select_slot.bind(slot))
			doll_grid.add_child(button)
			_slot_buttons[slot] = button


func _select_slot(slot: ItemData.Slot) -> void:
	_slot = slot
	_refresh()


func _toggle_item(item: ItemData) -> void:
	if SaveManager.get_equipped(_slot) == item:
		SaveManager.unequip(_slot)
	else:
		SaveManager.equip(item, _slot)
	_refresh()


func _refresh() -> void:
	hero_preview.show_hero(SaveManager.get_character())
	_refresh_doll()
	_refresh_item_list()
	_refresh_totals()


## Each slot: its name on top, what's in it below. Selected slot gets a marker (never color alone).
func _refresh_doll() -> void:
	for slot: ItemData.Slot in _slot_buttons:
		var equipped: ItemData = SaveManager.get_equipped(slot)
		var content: String = tr(equipped.name_key) if equipped else tr("UI_EMPTY_SLOT")
		if slot == ItemData.Slot.OFF_HAND and SaveManager.hands_full():
			content = tr("UI_HANDS_FULL")
		var marker: String = "» " if slot == _slot else ""
		(_slot_buttons[slot] as Button).text = "%s%s\n%s" % [marker, tr(ItemData.slot_key(slot)), content]


func _refresh_item_list() -> void:
	items_header.text = tr(ItemData.slot_key(_slot))
	for child: Node in item_list.get_children():
		child.queue_free()
	var fitting: Array[ItemData] = []
	for item: ItemData in ItemRegistry.all():
		if item.can_go_in(_slot) and SaveManager.has_item(str(item.id)):
			fitting.append(item)
	if fitting.is_empty():
		item_list.add_child(_make_hint(tr("UI_NOTHING_FOR_SLOT")))
		return
	for item: ItemData in fitting:
		var tag: String = ""
		if SaveManager.get_equipped(_slot) == item:
			tag = "  " + tr("UI_EQUIPPED_TAG")
		elif SaveManager.is_equipped(item):
			tag = "  " + tr("UI_OTHER_HAND_TAG")
		var hands: String = "  [%s]" % tr("ITEM_TWO_HANDED") if item.two_handed else ""
		var count: int = SaveManager.get_item_count(str(item.id))
		var copies: String = "  " + tr("UI_COUNT_TAG") % count if count > 1 else ""
		var button: Button = _make_button(Vector2(0, 48))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # Long skill lists wrap instead of widening the panel.
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s %s%s%s%s\n%s" % [tr("UI_TIER") % item.tier, tr(item.name_key), hands, copies, tag, _short_stats(item)]
		if not SaveManager.can_use_tier(item):
			button.disabled = true
			button.text += "\n" + tr("UI_REQUIRES") % Progression.requirement_text(Progression.MASTERY, item.category, item.tier)
		button.pressed.connect(_toggle_item.bind(item))
		item_list.add_child(button)


## "Max HP 80 (-20)   Attack 23 (+13)   Defense -2 (-2)": base stats + all equipped gear.
func _refresh_totals() -> void:
	var base: CharacterData = SaveManager.get_character()
	var totals: Dictionary = EquipmentComponent.totals(base.max_health, base.attack_power, base.defense,
		SaveManager.equipped_items())
	var parts: Array[String] = []
	for stat: Array in [["max_health", base.max_health, "STAT_MAX_HEALTH"],
			["attack_power", base.attack_power, "STAT_ATTACK"], ["defense", base.defense, "STAT_DEFENSE"]]:
		var total: int = totals[stat[0]]
		var diff: int = total - int(stat[1])
		var text: String = "%s %d" % [tr(stat[2]), total]
		if diff != 0:
			text += " [color=%s](%+d)[/color]" % [GOOD_COLOR if diff > 0 else BAD_COLOR, diff]
		parts.append(text)
	totals_label.text = "     ".join(parts)


func _short_stats(item: ItemData) -> String:
	var parts: Array[String] = []
	for stat: Array in [[item.max_health, "STAT_MAX_HEALTH"], [item.attack_power, "STAT_ATTACK"], [item.defense, "STAT_DEFENSE"]]:
		if stat[0] != 0:
			parts.append("%+d %s" % [stat[0], tr(stat[1])])
	if not item.skills.is_empty():
		parts.append(item.skills_text())
		parts.append(item.weight_text())
	if item.use_effect:
		parts.append(item.use_effect.describe())
	return "  ".join(parts)


func _make_button(min_size: Vector2) -> Button:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", 16)
	return button


func _make_hint(text: String) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 18)
	return label
