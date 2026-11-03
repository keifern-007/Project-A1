class_name MissionCategoryView
extends VBoxContainer
## The Mission Board's first page: Rogue (short roguelike missions) or Expeditions (the big maps).
## Built in code; the board shows it first and when you go back.

signal chosen(category: MapData.Category)
signal back

const CARD_SIZE: Vector2 = Vector2(420, 220)

var _buttons: Dictionary = {} # MapData.Category -> Button


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 30)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	add_child(row)
	_add_card(row, MapData.Category.ROGUE, "UI_ROGUE", "UI_ROGUE_DESC")
	_add_card(row, MapData.Category.EXPEDITION, "UI_EXPEDITIONS", "UI_EXPEDITIONS_DESC")
	var back_button: Button = Button.new()
	back_button.text = "UI_BACK"
	back_button.custom_minimum_size = Vector2(240, 48)
	back_button.add_theme_font_size_override("font_size", 22)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(back.emit)
	add_child(back_button)


## A big button: the category's name, then what it holds.
func _add_card(row: HBoxContainer, category: MapData.Category, title_key: String, description_key: String) -> void:
	var button: Button = Button.new()
	button.custom_minimum_size = CARD_SIZE
	button.pressed.connect(chosen.emit.bind(category))
	row.add_child(button)
	var text: VBoxContainer = VBoxContainer.new()
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 12)
	button.add_child(text)
	for part: Array in [[title_key, 34], [description_key, 18]]:
		var label: Label = Label.new()
		label.text = part[0]
		label.add_theme_font_size_override("font_size", part[1])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(label)
	_buttons[category] = button


func focus(category: MapData.Category) -> void:
	(_buttons[category] as Button).grab_focus()
