class_name SkillPickerView
extends VBoxContainer
## A hero's skill choices for the Skill Shrine: pick a key, then a skill from the list.
## Keys 1-2 come from the hero's pool and the shared pool (unlocked with skill points);
## keys 3-4 from the equipped weapon's pool (free). Each row says in words what its button does.
## The rules live in SkillChoices and SaveManager.

signal changed

const KEY_CELL_SIZE: Vector2 = Vector2(230, 58)
const ACTION_WIDTH: float = 170.0

var _character: CharacterData
var _hero_key: int = 0 ## Which of keys 1-2 is selected.
var _weapon_key: int = 0 ## Which of keys 3-4 is selected.


func show_skills(character: CharacterData) -> void:
	_character = character
	add_theme_constant_override("separation", 8)
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	add_child(_make_label(tr("UI_SKILLS_PICK_KEY"), 15))
	_build_hero_section()
	_build_weapon_section()


## First button that can be pressed, for keyboard/gamepad focus.
func first_action() -> Button:
	for button: Node in find_children("*", "Button", true, false):
		if not (button as Button).disabled:
			return button
	return null


func _build_hero_section() -> void:
	var entry: Dictionary = SaveManager.skill_entry(_character)
	var keys: Array[SkillData] = SkillChoices.hero_keys(entry, _character)
	add_child(_make_header(tr("UI_SKILLS_HERO_HEADER")))
	add_child(_make_key_row(keys, 1, _hero_key, func(index: int) -> void: _hero_key = index))
	var pool: Array[SkillData] = _character.signature_skills.duplicate()
	pool.append_array(_character.skill_pool)
	for skill: SkillData in pool:
		add_child(_make_hero_row(skill, keys))
	var shared: Array[SkillData] = SkillRegistry.all().filter(func(skill: SkillData) -> bool: return skill.shared)
	if not shared.is_empty():
		add_child(_make_label(tr("UI_SKILLS_SHARED"), 16))
		for skill: SkillData in shared:
			add_child(_make_hero_row(skill, keys))


func _build_weapon_section() -> void:
	var weapon: ItemData = SaveManager.get_equipped(ItemData.Slot.MAIN_HAND, str(_character.id))
	var keys: Array[SkillData] = SkillChoices.weapon_keys_or_default(SaveManager.skill_entry(_character), weapon)
	add_child(_make_header(tr("UI_SKILLS_WEAPON_HEADER") % (tr(weapon.name_key) if weapon else tr("UI_UNARMED"))))
	add_child(_make_label(tr("UI_SKILLS_WEAPON_HINT"), 15))
	add_child(_make_key_row(keys, 3, _weapon_key, func(index: int) -> void: _weapon_key = index))
	for skill: SkillData in SkillChoices.weapon_pool(weapon):
		add_child(_make_weapon_row(skill, keys, weapon))


## Two cells: the key and what's on it. The selected one gets a marker, not just a shade.
func _make_key_row(skills: Array[SkillData], first_key: int, selected: int, on_select: Callable) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for i: int in 2:
		var button: Button = _make_button("%s[%s]\n%s" % ["» " if i == selected else "", InputHints.key_for("skill_%d" % (first_key + i)), skills[i].display_name()])
		button.custom_minimum_size = KEY_CELL_SIZE
		button.pressed.connect(func() -> void:
			on_select.call(i)
			changed.emit())
		row.add_child(button)
	return row


func _make_hero_row(skill: SkillData, keys: Array[SkillData]) -> Control:
	var entry: Dictionary = SaveManager.skill_entry(_character)
	var button: Button = _make_button("")
	if not SkillChoices.is_unlocked(entry, _character, skill):
		var cost: int = SkillChoices.unlock_cost(skill)
		var block: StringName = SaveManager.skill_unlock_block(_character, skill)
		button.text = tr("UI_SKILL_UNLOCK") % cost if block == &"" else tr("UI_SKILL_NEEDS_POINTS") % cost
		button.disabled = block != &""
		button.pressed.connect(func() -> void:
			SaveManager.unlock_skill(_character, skill)
			changed.emit())
		return _make_row(skill, button)
	var pair: Array[SkillData] = _pair_with(keys, _hero_key, skill)
	if keys[_hero_key] == skill:
		button.text = tr("UI_SKILL_ON_KEY") % InputHints.key_for("skill_%d" % (_hero_key + 1))
		button.disabled = true
	elif SkillChoices.hero_keys_block(entry, _character, pair[0], pair[1]) == &"two_shared":
		button.text = tr("UI_SKILL_ONE_SHARED")
		button.disabled = true
	else:
		button.text = _put_text(keys, _hero_key, skill, 1)
		button.pressed.connect(func() -> void:
			SaveManager.set_hero_keys(_character, pair[0], pair[1])
			changed.emit())
	return _make_row(skill, button)


func _make_weapon_row(skill: SkillData, keys: Array[SkillData], weapon: ItemData) -> Control:
	var button: Button = _make_button("")
	if keys[_weapon_key] == skill:
		button.text = tr("UI_SKILL_ON_KEY") % InputHints.key_for("skill_%d" % (_weapon_key + 3))
		button.disabled = true
	else:
		var pair: Array[SkillData] = _pair_with(keys, _weapon_key, skill)
		button.text = _put_text(keys, _weapon_key, skill, 3)
		button.pressed.connect(func() -> void:
			SaveManager.set_weapon_keys(_character, weapon, pair[0], pair[1])
			changed.emit())
	return _make_row(skill, button)


## The two keys after putting `skill` on the selected one. If it's on the other key, they swap.
func _pair_with(keys: Array[SkillData], selected: int, skill: SkillData) -> Array[SkillData]:
	var pair: Array[SkillData] = keys.duplicate()
	if pair[1 - selected] == skill:
		pair[1 - selected] = pair[selected]
	pair[selected] = skill
	return pair


func _put_text(keys: Array[SkillData], selected: int, skill: SkillData, first_key: int) -> String:
	if keys[1 - selected] == skill:
		return tr("UI_SKILL_SWAP")
	return tr("UI_SKILL_PUT") % InputHints.key_for("skill_%d" % (first_key + selected))


## Name and numbers on the left, what the button does on the right.
func _make_row(skill: SkillData, button: Button) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	text.add_child(_make_label(skill.display_name(), 17))
	text.add_child(_make_label(_numbers_of(skill), 14))
	row.add_child(text)
	button.custom_minimum_size = Vector2(ACTION_WIDTH, 38)
	row.add_child(button)
	return row


## "25 MP  |  6s cooldown  |  0.2s wind-up"
func _numbers_of(skill: SkillData) -> String:
	var cost_key: String = "HUD_COST_MANA" if skill.kind == SkillData.Kind.MAGIC else "HUD_COST_STAMINA"
	return tr("UI_SKILL_NUMBERS") % [tr(cost_key) % roundi(skill.cost), roundi(skill.cooldown), skill.cast_time]


func _make_header(text: String) -> Label:
	var label: Label = _make_label(text, 20)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	return label


func _make_button(text: String) -> Button:
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.text = text
	button.add_theme_font_size_override("font_size", 15)
	return button


func _make_label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label
