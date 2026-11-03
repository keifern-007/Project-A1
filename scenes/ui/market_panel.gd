extends Control
## The camp's Marketplace: buy potions with coins, sell spare materials and gear for coins.
## Rules and prices live in Market; this only shows them. Worn or packed copies can't be sold.

signal closed

enum Tab { BUY, SELL }

const SWATCH_SIZE: Vector2 = Vector2(18, 18)
const BUTTON_SIZE: Vector2 = Vector2(120, 40)
const CONFIRM_TIME: float = 3.0 ## Seconds a 'Sell all' stays armed for its second press.

var _tab: Tab = Tab.BUY
var _buttons: Dictionary = {} # key -> Button, to keep focus on the same button after a rebuild.
var _armed: String = "" # Key of the 'Sell all' waiting for its second press.
var _armed_at: int = 0

@onready var coins_label: Label = %CoinsLabel
@onready var buy_tab: Button = %BuyTab
@onready var sell_tab: Button = %SellTab
@onready var list: VBoxContainer = %List
@onready var message: Label = %Message
@onready var back_button: Button = %BackButton


func _ready() -> void:
	back_button.pressed.connect(closed.emit)
	buy_tab.pressed.connect(_show_tab.bind(Tab.BUY))
	sell_tab.pressed.connect(_show_tab.bind(Tab.SELL))
	message.text = ""
	_show_tab(Tab.BUY)
	buy_tab.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _show_tab(tab: Tab) -> void:
	_tab = tab
	_armed = ""
	message.text = ""
	_rebuild()


func _rebuild(focus_key: String = "") -> void:
	coins_label.text = tr("UI_COINS_OWNED") % Market.coins()
	# The open tab is marked with text, not only by looking pressed.
	buy_tab.text = ("» " if _tab == Tab.BUY else "") + tr("UI_MARKET_BUY")
	sell_tab.text = ("» " if _tab == Tab.SELL else "") + tr("UI_MARKET_SELL")
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()
	_buttons.clear()
	if _tab == Tab.BUY:
		_fill_buy()
	else:
		_fill_sell()
	if _buttons.has(focus_key) and not (_buttons[focus_key] as Button).disabled:
		(_buttons[focus_key] as Button).grab_focus()


func _fill_buy() -> void:
	list.add_child(_label(tr("UI_MARKET_BUY_HINT"), 16, true))
	for item: ItemData in Market.stock():
		var info: String = tr("UI_MARKET_BUY_INFO") % [item.use_effect.describe() if item.use_effect else "",
			SaveManager.get_item_count(str(item.id))]
		var row: HBoxContainer = _row(tr(item.name_key), item.color, info)
		var key: String = "buy/" + str(item.id)
		var button: Button = _button(row, key, tr("UI_MARKET_BUY_BUTTON") % item.shop_price)
		button.disabled = not Market.can_buy(item)
		button.pressed.connect(_on_buy.bind(item, key))
		if button.disabled:
			button.tooltip_text = tr("UI_MARKET_NO_COINS")
			button.text += "\n" + tr("UI_MARKET_NO_COINS")


func _fill_sell() -> void:
	var materials: Dictionary = SaveManager.profile["materials"]
	var ids: Array = materials.keys()
	ids.sort()
	list.add_child(_label(tr("UI_MARKET_MATERIALS"), 20))
	if ids.is_empty():
		list.add_child(_label(tr("UI_MARKET_NOTHING"), 16, true))
	for id: String in ids:
		var material: MaterialData = MaterialRegistry.get_by_id(id)
		if material == null:
			continue
		var count: int = SaveManager.get_material_count(id)
		var price: int = Market.material_price(material)
		var row: HBoxContainer = _row(tr(material.name_key), material.color, tr("UI_MARKET_SELL_INFO") % [count, price])
		_sell_buttons(row, "mat/" + id, count, price, func(amount: int) -> int: return Market.sell_material(material, amount))
	list.add_child(_label(tr("UI_MARKET_ITEMS"), 20))
	var any_item: bool = false
	for item: ItemData in ItemRegistry.all():
		var id: String = str(item.id)
		var owned: int = SaveManager.get_item_count(id)
		var price: int = Market.item_price(item)
		if owned <= 0 or price <= 0:
			continue
		any_item = true
		var free: int = Market.sellable_items(id)
		var info: String = tr("UI_MARKET_SELL_INFO") % [owned, price]
		if free < owned:
			info += "  " + tr("UI_MARKET_IN_USE") % (owned - free)
		var row: HBoxContainer = _row(tr(item.name_key), item.color, info)
		_sell_buttons(row, "item/" + id, free, price, func(amount: int) -> int: return Market.sell_item(item, amount))
	if not any_item:
		list.add_child(_label(tr("UI_MARKET_NOTHING"), 16, true))


## 'Sell 1' and 'Sell all' (the second needs a second press, so a slip can't sell a whole stack).
func _sell_buttons(row: HBoxContainer, key: String, free: int, price: int, sell: Callable) -> void:
	var one: Button = _button(row, key + "/1", tr("UI_MARKET_SELL_ONE") % price)
	one.disabled = free <= 0
	one.pressed.connect(_on_sell.bind(sell, 1, key + "/1"))
	var all_text: String = tr("UI_MARKET_SELL_ALL") % (free * price)
	if _armed == key + "/all":
		all_text = tr("UI_MARKET_CONFIRM")
	var all: Button = _button(row, key + "/all", all_text)
	all.disabled = free <= 1
	all.pressed.connect(_on_sell_all.bind(sell, free, key + "/all"))
	if free <= 0:
		one.text += "\n" + tr("UI_MARKET_ALL_IN_USE")


func _on_buy(item: ItemData, key: String) -> void:
	if Market.buy(item):
		message.text = tr("UI_MARKET_BOUGHT") % [tr(item.name_key), item.shop_price]
	_rebuild(key)


func _on_sell(sell: Callable, amount: int, key: String) -> void:
	_armed = ""
	var earned: int = sell.call(amount)
	if earned > 0:
		message.text = tr("UI_MARKET_SOLD") % [amount, earned]
	_rebuild(key)


func _on_sell_all(sell: Callable, amount: int, key: String) -> void:
	if _armed != key or Time.get_ticks_msec() - _armed_at > CONFIRM_TIME * 1000:
		_armed = key
		_armed_at = Time.get_ticks_msec()
		_rebuild(key)
		return
	_on_sell(sell, amount, key)


## Swatch + name, then the details, then room for buttons. The name carries the meaning; the swatch is a hint.
func _row(title: String, color: Color, info: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var swatch: ColorRect = ColorRect.new()
	swatch.custom_minimum_size = SWATCH_SIZE
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.color = color
	row.add_child(swatch)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	text.add_child(_label(title, 19))
	text.add_child(_label(info, 15, true))
	row.add_child(text)
	list.add_child(row)
	return row


func _button(row: HBoxContainer, key: String, text: String) -> Button:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.custom_minimum_size = BUTTON_SIZE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 15)
	button.text = text
	row.add_child(button)
	_buttons[key] = button
	return button


func _label(text: String, size: int, dim: bool = false) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	if dim:
		label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	return label
