class_name TalentTreeView
extends VBoxContainer
## A hero's talent tree for the Skill Shrine: one row per tier, a card per talent with its
## effects and a Learn button. Locked talents say why in words (never by color alone).
## The rules live in SaveManager (talent_block / buy_talent).

signal learned(talent: TalentData)

const CARD_WIDTH: float = 330.0
const BLOCK_KEYS: Dictionary = {
	&"owned": "UI_TALENT_OWNED",
	&"other_chosen": "UI_TALENT_OTHER_CHOSEN",
	&"needs_tier": "UI_TALENT_NEEDS_TIER",
	&"no_points": "UI_TALENT_NO_POINTS",
}

var _character: CharacterData


func show_tree(character: CharacterData) -> void:
	_character = character
	add_theme_constant_override("separation", 10)
	for child: Node in get_children():
		child.queue_free()
	for tier: int in range(1, 4):
		var in_tier: Array[TalentData] = character.talents.filter(func(t: TalentData) -> bool: return t.tier == tier)
		if in_tier.is_empty():
			continue
		var choice: bool = in_tier.any(func(t: TalentData) -> bool: return t.exclusive_group != &"")
		add_child(_make_label(tr("UI_TALENT_TIER_CHOICE" if choice else "UI_TALENT_TIER") % tier, 20))
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		add_child(row)
		for talent: TalentData in in_tier:
			row.add_child(_make_card(talent))


## First Learn button that can be pressed, for keyboard/gamepad focus. null if none.
func first_learnable() -> Button:
	for button: Node in find_children("*", "Button", true, false):
		if not (button as Button).disabled:
			return button
	return null


func _make_card(talent: TalentData) -> Control:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var block: StringName = SaveManager.talent_block(_character, talent)
	var owned_mark: String = "✔ " if block == &"owned" else ""
	box.add_child(_make_label(owned_mark + tr(talent.name_key), 19))
	for line: String in talent.effect_lines():
		box.add_child(_make_label("  " + line, 16))
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.add_theme_font_size_override("font_size", 16)
	if block == &"":
		button.text = tr("UI_TALENT_COST") % talent.cost()
	elif block == &"needs_tier":
		button.text = tr(BLOCK_KEYS[block]) % (talent.tier - 1)
	else:
		button.text = tr(BLOCK_KEYS[block])
	button.disabled = block != &""
	button.pressed.connect(_learn.bind(talent))
	box.add_child(button)
	return card


func _learn(talent: TalentData) -> void:
	if SaveManager.buy_talent(_character, talent):
		learned.emit(talent)


func _make_label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label
