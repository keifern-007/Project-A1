extends Control
## The camp's Forge: pick a recipe, see its stats and material cost, craft it.
## All the rules (affordable? already owned? spend materials) live in SaveManager.

signal closed

const GOOD_COLOR: String = "#9be37a"
const BAD_COLOR: String = "#f08a7a"

var _selected: ItemData
var _buttons: Dictionary = {} # ItemData -> Button

@onready var recipe_list: VBoxContainer = %RecipeList
@onready var name_label: Label = %NameLabel
@onready var slot_label: Label = %SlotLabel
@onready var stats_label: RichTextLabel = %StatsLabel
@onready var description_label: Label = %DescriptionLabel
@onready var cost_list: VBoxContainer = %CostList
@onready var craft_button: Button = %CraftButton
@onready var message_label: Label = %MessageLabel
@onready var back_button: Button = %BackButton


func _ready() -> void:
	var group: ButtonGroup = ButtonGroup.new()
	for item: ItemData in ItemRegistry.all():
		var button: Button = Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.custom_minimum_size = Vector2(260, 44)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_select.bind(item))
		button.toggled.connect(func(_on: bool) -> void: _refresh_buttons())
		recipe_list.add_child(button)
		_buttons[item] = button
	craft_button.pressed.connect(_craft)
	back_button.pressed.connect(closed.emit)
	message_label.text = ""
	_refresh_buttons()
	if not _buttons.is_empty():
		var first: Button = _buttons.values()[0]
		first.button_pressed = true
		first.grab_focus()
		_select(_buttons.keys()[0])


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
	name_label.text = tr(item.name_key)
	var slot_text: String = "%s  |  %s" % [tr("UI_TIER") % item.tier, tr(ItemData.slot_key(item.slot))]
	if item.two_handed:
		slot_text += "  |  " + tr("ITEM_TWO_HANDED")
	slot_label.text = slot_text
	stats_label.text = "\n".join(_stat_lines(item))
	description_label.text = tr(item.description_key)
	for child: Node in cost_list.get_children():
		child.queue_free()
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
