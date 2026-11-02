class_name InventoryView
extends VBoxContainer
## The Gear Rack's Inventory, Minecraft style. Top: the slots this hero carries on missions.
## Below: the potions left in camp. Click picks up and places a stack (merging or swapping);
## right click takes half or places one. What you hold isn't saved anywhere: put down, or if the
## panel closes, it's simply back in camp. The rules live in SaveManager.

signal changed

const CELL_SIZE: Vector2 = Vector2(140, 60)
const COLUMNS: int = 3
const HAND_OFFSET: Vector2 = Vector2(16, 16)

var _hand_id: String = ""
var _hand_count: int = 0
var _pack_buttons: Array[Button] = []
var _stash_buttons: Dictionary = {} # item id -> Button
var _hand_label: Label
var _status_label: Label
var _details_label: Label
var _none_label: Label


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(_make_label(tr("UI_INVENTORY_PACK"), true))
	var pack_grid: GridContainer = _make_grid()
	for i: int in SaveManager.PACK_SLOTS:
		var button: Button = _make_cell()
		button.pressed.connect(_on_pack_left.bind(i))
		button.gui_input.connect(_on_cell_input.bind(_on_pack_right.bind(i)))
		button.mouse_entered.connect(_show_pack_details.bind(i))
		button.focus_entered.connect(_show_pack_details.bind(i))
		pack_grid.add_child(button)
		_pack_buttons.append(button)
	add_child(_make_label(tr("UI_INVENTORY_STASH"), true))
	_none_label = _make_label(tr("UI_INVENTORY_NONE"), false)
	add_child(_none_label)
	var stash_grid: GridContainer = _make_grid()
	for item: ItemData in ItemRegistry.all():
		if item.slot == ItemData.Slot.CONSUMABLE:
			var id: String = str(item.id)
			var button: Button = _make_cell()
			button.pressed.connect(_on_stash_left.bind(id))
			button.gui_input.connect(_on_cell_input.bind(_on_stash_right.bind(id)))
			button.mouse_entered.connect(_show_details.bind(item))
			button.focus_entered.connect(_show_details.bind(item))
			stash_grid.add_child(button)
			_stash_buttons[id] = button
	_status_label = _make_label("", false)
	add_child(_status_label)
	_details_label = _make_label("", false)
	add_child(_details_label)
	_hand_label = Label.new()
	_hand_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_hand_label.top_level = true
	_hand_label.z_index = 10
	_hand_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_label.add_theme_font_size_override("font_size", 18)
	_hand_label.add_theme_constant_override("outline_size", 6)
	_hand_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_hand_label)
	refresh()


func _process(_delta: float) -> void:
	_hand_label.global_position = get_global_mouse_position() + HAND_OFFSET


## Anything held goes back to camp (the Gear Rack switched to another slot).
func drop_hand() -> void:
	_set_hand("", 0)
	refresh()


func refresh() -> void:
	var pack: Array = SaveManager.get_pack()
	for i: int in _pack_buttons.size():
		var entry: Dictionary = pack[i]
		_pack_buttons[i].text = _cell_text(str(entry.get("id", "")), int(entry.get("count", 0)))
	var any_owned: bool = false
	for id: String in _stash_buttons:
		var owned: bool = SaveManager.has_item(id)
		any_owned = any_owned or owned
		var button: Button = _stash_buttons[id]
		button.visible = owned
		var left: int = _camp_count(id)
		button.text = _cell_text(id, left) if left > 0 else "%s\n%s" % [_item_name(id), tr("UI_INVENTORY_ALL_PACKED")]
		button.modulate.a = 1.0 if left > 0 else 0.5 # Dimmed, and it says so in words.
	_none_label.visible = not any_owned
	if _hand_id == "":
		_status_label.text = tr("UI_INVENTORY_HELP")
		_hand_label.text = ""
	else:
		_hand_label.text = _cell_text(_hand_id, _hand_count).replace("\n", " ")
		_status_label.text = tr("UI_INVENTORY_HOLDING") % [_item_name(_hand_id), _hand_count]


func _on_pack_left(index: int) -> void:
	var entry: Dictionary = SaveManager.get_pack()[index]
	var slot_id: String = str(entry.get("id", ""))
	var slot_count: int = int(entry.get("count", 0))
	if _hand_id == "":
		if slot_id != "":
			SaveManager.set_pack_slot(index, "", 0)
			_set_hand(slot_id, slot_count)
	elif slot_id == "" or slot_id == _hand_id:
		var moved: int = mini(_hand_count, _room_in(slot_id, slot_count))
		SaveManager.set_pack_slot(index, _hand_id, slot_count + moved)
		_set_hand(_hand_id, _hand_count - moved)
	else: # Different potion: swap what's held with what's there.
		SaveManager.set_pack_slot(index, "", 0)
		SaveManager.set_pack_slot(index, _hand_id, _hand_count)
		_set_hand(slot_id, slot_count)
	_finish_change()


func _on_pack_right(index: int) -> void:
	var entry: Dictionary = SaveManager.get_pack()[index]
	var slot_id: String = str(entry.get("id", ""))
	var slot_count: int = int(entry.get("count", 0))
	if _hand_id == "":
		if slot_id != "":
			var half: int = ceili(slot_count / 2.0)
			SaveManager.set_pack_slot(index, slot_id if slot_count > half else "", slot_count - half)
			_set_hand(slot_id, half)
	elif (slot_id == "" or slot_id == _hand_id) and _room_in(slot_id, slot_count) > 0:
		SaveManager.set_pack_slot(index, _hand_id, slot_count + 1)
		_set_hand(_hand_id, _hand_count - 1)
	_finish_change()


func _on_stash_left(id: String) -> void:
	if _hand_id != "":
		_set_hand("", 0) # Put it back in camp.
	else:
		var take: int = mini(_camp_count(id), ItemRegistry.get_by_id(id).stack_size)
		if take > 0:
			_set_hand(id, take)
	_finish_change()


func _on_stash_right(id: String) -> void:
	var fits: bool = _hand_id == "" or (_hand_id == id and _hand_count < ItemRegistry.get_by_id(id).stack_size)
	if fits and _camp_count(id) > 0:
		_set_hand(id, _hand_count + 1)
	_finish_change()


# Right click on a cell. Left click and gamepad/keyboard presses go through the button's `pressed`.
func _on_cell_input(event: InputEvent, on_right_click: Callable) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		on_right_click.call()


func _set_hand(id: String, count: int) -> void:
	_hand_count = count if id != "" else 0
	_hand_id = id if _hand_count > 0 else ""


func _finish_change() -> void:
	refresh()
	changed.emit()


## Copies in camp: not in any hero's slots, and not in your hand.
func _camp_count(id: String) -> int:
	return SaveManager.pack_available(id) - (_hand_count if id == _hand_id else 0)


func _room_in(slot_id: String, slot_count: int) -> int:
	return ItemRegistry.get_by_id(_hand_id).stack_size - (slot_count if slot_id != "" else 0)


func _show_pack_details(index: int) -> void:
	var id: String = str(SaveManager.get_pack()[index].get("id", ""))
	_details_label.text = _details_of(ItemRegistry.get_by_id(id)) if id != "" else ""


func _show_details(item: ItemData) -> void:
	_details_label.text = _details_of(item)


func _details_of(item: ItemData) -> String:
	var parts: Array[String] = [tr(item.name_key)]
	if item.use_effect:
		parts.append(item.use_effect.describe())
	parts.append(tr("UI_USE_COOLDOWN") % roundi(item.use_cooldown))
	parts.append(tr("UI_STACK_SIZE") % item.stack_size)
	return "  |  ".join(parts)


func _cell_text(id: String, count: int) -> String:
	return tr("UI_EMPTY_SLOT") if id == "" else "%s\n%s" % [_item_name(id), tr("UI_COUNT_TAG") % count]


func _item_name(id: String) -> String:
	return tr(ItemRegistry.get_by_id(id).name_key)


func _make_grid() -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	return grid


func _make_cell() -> Button:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.custom_minimum_size = CELL_SIZE
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 15)
	# Each slot needs a visible edge to read as a grid. Hover and focus get a thicker one, not just a color.
	button.add_theme_stylebox_override("normal", _cell_style(1, Color(0.6, 0.6, 0.65)))
	button.add_theme_stylebox_override("pressed", _cell_style(1, Color(0.6, 0.6, 0.65)))
	button.add_theme_stylebox_override("hover", _cell_style(2, Color(0.9, 0.9, 0.95)))
	button.add_theme_stylebox_override("focus", _cell_style(3, Color.WHITE))
	return button


func _cell_style(border: int, color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.14, 0.17)
	style.border_color = color
	style.set_border_width_all(border)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(4.0)
	return style


func _make_label(text: String, header: bool) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 18 if header else 15)
	if header:
		label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	return label
