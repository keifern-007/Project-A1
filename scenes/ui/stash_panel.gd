extends Control
## The camp's Stash: every material in the saved profile, plus run stats.

signal closed

const SWATCH_SIZE: Vector2 = Vector2(18, 18)

@onready var list: VBoxContainer = %List
@onready var stats_label: Label = %StatsLabel
@onready var back_button: Button = %BackButton


func _ready() -> void:
	back_button.pressed.connect(closed.emit)
	back_button.grab_focus()
	var stats: Dictionary = SaveManager.profile["stats"]
	stats_label.text = tr("UI_STASH_STATS") % [stats["runs_played"], stats["runs_won"]]
	var materials: Dictionary = SaveManager.profile["materials"]
	if materials.is_empty():
		list.add_child(_make_label(tr("UI_STASH_EMPTY")))
		return
	var ids: Array = materials.keys()
	ids.sort()
	for id: String in ids:
		list.add_child(_make_row(MaterialRegistry.get_by_id(id), id, materials[id]))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


## Swatch + name + count (the name carries the meaning; the swatch is a hint).
func _make_row(material: MaterialData, id: String, count: int) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var swatch: ColorRect = ColorRect.new()
	swatch.custom_minimum_size = SWATCH_SIZE
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.color = material.color if material else Color.WHITE
	row.add_child(swatch)
	var name_text: String = tr(material.name_key) if material else id
	row.add_child(_make_label(tr("UI_REWARD_ROW") % [name_text, count]))
	return row


func _make_label(text: String) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	return label
