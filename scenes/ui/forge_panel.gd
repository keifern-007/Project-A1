extends Control
## The camp's Forge: pick a recipe, see its stats and material cost, craft it.
## All the rules (affordable? already owned? spend materials) live in SaveManager.

signal closed

const GOOD_COLOR: String = "#9be37a"
const BAD_COLOR: String = "#f08a7a"

var _selected: ItemData
var _buttons: Dictionary = {} # ItemData -> Button
var _headers: Dictionary = {} # ItemData.Slot -> Label, the name above that set in the 'All' list
var _recipe_group: ButtonGroup = ButtonGroup.new()

@onready var filters: ForgeFilters = %Filters
@onready var empty_label: Label = %EmptyLabel
@onready var recipe_list: VBoxContainer = %RecipeList
@onready var item_preview: ModelPreview = %ItemPreview
@onready var name_label: Label = %NameLabel
@onready var slot_label: Label = %SlotLabel
@onready var stats_label: RichTextLabel = %StatsLabel
@onready var description_label: Label = %DescriptionLabel
@onready var cost_header: Label = %CostHeader
@onready var cost_list: VBoxContainer = %CostList
@onready var craft_button: Button = %CraftButton
@onready var message_label: Label = %MessageLabel
@onready var back_button: Button = %BackButton


func _ready() -> void:
	_build_recipe_list()
	filters.changed.connect(_apply_filters)
	craft_button.pressed.connect(_craft)
	back_button.pressed.connect(closed.emit)
	message_label.text = ""
	_refresh_buttons()
	_apply_filters()
	if _selected:
		_buttons[_selected].grab_focus()


func _build_recipe_list() -> void:
	var last_slot: int = ItemFilter.ALL_SETS
	for item: ItemData in ItemRegistry.all():
		if item.slot != last_slot:
			last_slot = item.slot
			var header: Label = Label.new()
			header.text = ItemData.set_key(item.slot)
			header.add_theme_font_size_override("font_size", 17)
			header.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
			recipe_list.add_child(header)
			_headers[item.slot] = header
		var button: Button = Button.new()
		button.toggle_mode = true
		button.button_group = _recipe_group
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(290, 40)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_select.bind(item))
		button.toggled.connect(func(_on: bool) -> void: _refresh_buttons())
		recipe_list.add_child(button)
		_buttons[item] = button


## Shows only what passes the filter, and moves the selection if it just got hidden.
func _apply_filters() -> void:
	var first_visible: ItemData = null
	for slot: int in _headers:
		_headers[slot].visible = false
	for item: ItemData in _buttons:
		var shown: bool = filters.filter.matches(item)
		_buttons[item].visible = shown
		if shown:
			_headers[item.slot].visible = filters.filter.set_slot == ItemFilter.ALL_SETS
			if first_visible == null:
				first_visible = item
	empty_label.visible = first_visible == null
	if _selected == null or not filters.filter.matches(_selected):
		if first_visible:
			_buttons[first_visible].button_pressed = true
		_select(first_visible)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _select(item: ItemData) -> void:
	_selected = item
	message_label.text = ""
	_refresh_details()


func _craft() -> void:
	if SaveManager.craft(_selected):
		message_label.text = tr("UI_CRAFTED") % tr(_selected.name_key)
		filters.refresh_materials() # Owned counts changed.
		_refresh_buttons()
		_refresh_details()


func _refresh_buttons() -> void:
	for item: ItemData in _buttons:
		var button: Button = _buttons[item]
		var count: int = SaveManager.get_item_count(str(item.id))
		var owned: String = "  " + tr("UI_COUNT_TAG") % count if count > 0 else ""
		if not SaveManager.can_craft_tier(item):
			owned += "  " + tr("UI_LOCKED_TAG")
		# Selection gets a marker, not just a darker shade (never color alone).
		var marker: String = "»  " if button.button_pressed else ""
		button.text = marker + tr(item.name_key) + owned


func _refresh_details() -> void:
	var item: ItemData = _selected
	item_preview.show_item(item)
	for child: Node in cost_list.get_children():
		child.queue_free()
	craft_button.disabled = item == null
	cost_header.visible = item != null
	if item == null: # The filters hide every recipe.
		name_label.text = ""
		slot_label.text = ""
		stats_label.text = ""
		description_label.text = ""
		return
	name_label.text = tr(item.name_key)
	var slot_text: String = "%s  |  %s" % [tr("UI_TIER") % item.tier, tr(ItemData.slot_key(item.slot))]
	if item.two_handed:
		slot_text += "  |  " + tr("ITEM_TWO_HANDED")
	slot_label.text = slot_text + "  |  " + tr(ItemData.style_key(item.style))
	stats_label.text = "\n".join(_stat_lines(item))
	description_label.text = tr(item.description_key)
	for cost: MaterialCost in item.cost:
		cost_list.add_child(_make_cost_row(cost))
	if not SaveManager.can_craft_tier(item):
		var track: String = Progression.track_key(Progression.CRAFTING, item.category)
		cost_list.add_child(_make_plain_row(tr("UI_REQUIRES_YOU") % [Progression.requirement_text(
			Progression.CRAFTING, item.category, item.tier), SaveManager.get_track_level(track)]))
	if Progression.trains_mastery(item) and not SaveManager.can_use_tier(item):
		cost_list.add_child(_make_plain_row(tr("UI_TO_EQUIP") % Progression.requirement_text(
			Progression.MASTERY, item.category, item.tier)))
	craft_button.text = tr("UI_CRAFT")
	craft_button.disabled = not SaveManager.can_craft(item)


## "+8 Attack" / "-2 Defense". The sign carries the meaning; green/red is only a hint.
func _stat_lines(item: ItemData) -> Array[String]:
	var lines: Array[String] = []
	for stat: Array in [[item.max_health, "STAT_MAX_HEALTH"], [item.attack_power, "STAT_ATTACK"], [item.defense, "STAT_DEFENSE"]]:
		var value: int = stat[0]
		if value != 0:
			var color: String = GOOD_COLOR if value > 0 else BAD_COLOR
			lines.append("[color=%s]%+d %s[/color]" % [color, value, tr(stat[1])])
	if not item.skills.is_empty():
		lines.append(item.skills_text())
		lines.append(item.weight_text())
	if item.use_effect:
		lines.append(item.use_effect.describe())
		lines.append(tr("UI_USE_COOLDOWN") % roundi(item.use_cooldown))
	return lines


func _make_cost_row(cost: MaterialCost) -> Control:
	var have: int = SaveManager.get_material_count(str(cost.material.id))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var swatch: ColorRect = ColorRect.new()
	swatch.custom_minimum_size = Vector2(16, 16)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.color = cost.material.color
	row.add_child(swatch)
	var text: String = tr("UI_COST_ROW") % [tr(cost.material.name_key), have, cost.amount]
	if have < cost.amount:
		text += "   " + tr("UI_COST_SHORT") % (cost.amount - have)
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	row.add_child(label)
	return row


func _make_plain_row(text: String) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	return label
