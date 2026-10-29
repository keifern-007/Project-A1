extends Control
## The camp's Skill Shrine: your Rank and unspent skill points, then two tabs:
## Tracks (Gathering, Crafting, Mastery: "+ Level" spends a point) and the current hero's
## Talents (TalentTreeView). The rules live in SaveManager (level_track, buy_talent).

signal closed

const NAME_WIDTH: float = 260.0
const LEVEL_WIDTH: float = 80.0
const HINT_WIDTH: float = 200.0

var _level_labels: Dictionary = {} # track key -> Label
var _hint_labels: Dictionary = {} # track key -> Label
var _buttons: Dictionary = {} # track key -> Button
var _talent_view: TalentTreeView = TalentTreeView.new()

@onready var rank_label: Label = %RankLabel
@onready var rank_bar: ProgressBar = %RankBar
@onready var points_label: Label = %PointsLabel
@onready var track_list: VBoxContainer = %TrackList
@onready var content: VBoxContainer = %Content
@onready var tracks_tab: Button = %TracksTab
@onready var talents_tab: Button = %TalentsTab
@onready var back_button: Button = %BackButton


func _ready() -> void:
	back_button.pressed.connect(closed.emit)
	var rank_progress: Vector2i = Progression.progress(SaveManager.get_rank_xp())
	rank_label.text = tr("UI_RANK_ROW") % [SaveManager.get_rank(), rank_progress.x, rank_progress.y]
	rank_bar.max_value = rank_progress.y
	rank_bar.value = rank_progress.x
	var keys: Array[String] = Progression.all_track_keys()
	for kind: String in Progression.KINDS:
		track_list.add_child(_make_header(tr("UI_KIND_" + kind.to_upper())))
		var kind_keys: Array[String] = []
		for key: String in keys:
			if Progression.kind_of(key) == kind:
				kind_keys.append(key)
		kind_keys.sort_custom(func(a: String, b: String) -> bool: return Progression.display_name(a) < Progression.display_name(b))
		for key: String in kind_keys:
			track_list.add_child(_make_row(key))
	content.add_child(_talent_view)
	_talent_view.learned.connect(func(_talent: TalentData) -> void: _show_talents())
	var tabs: ButtonGroup = ButtonGroup.new()
	tracks_tab.button_group = tabs
	talents_tab.button_group = tabs
	tracks_tab.text = tr("UI_TAB_TRACKS")
	talents_tab.text = tr("UI_TAB_TALENTS") % tr(SaveManager.get_character().name_key)
	tracks_tab.pressed.connect(_show_tracks)
	talents_tab.pressed.connect(_show_talents)
	tracks_tab.button_pressed = true
	_show_tracks()


func _show_tracks() -> void:
	track_list.show()
	_talent_view.hide()
	_refresh()
	# Focus the first track you can level, else the tab.
	for key: String in _buttons:
		if not (_buttons[key] as Button).disabled:
			(_buttons[key] as Button).grab_focus()
			return
	tracks_tab.grab_focus()


func _show_talents() -> void:
	track_list.hide()
	_talent_view.show()
	_talent_view.show_tree(SaveManager.get_character())
	_refresh()
	await get_tree().process_frame # The rebuilt cards exist next frame.
	var button: Button = _talent_view.first_learnable()
	if button:
		button.grab_focus()
	else:
		talents_tab.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _level_up(key: String) -> void:
	if SaveManager.level_track(key):
		_refresh()
	if (_buttons[key] as Button).disabled: # Out of points: don't leave focus on a dead button.
		back_button.grab_focus()


func _refresh() -> void:
	points_label.text = tr("UI_SKILL_POINTS") % SaveManager.get_skill_points()
	for key: String in _buttons:
		var level: int = SaveManager.get_track_level(key)
		(_level_labels[key] as Label).text = tr("UI_TRACK_LEVEL") % level
		var tier: int = Progression.next_tier(level)
		(_hint_labels[key] as Label).text = tr("UI_NEXT_TIER") % [tier, Progression.level_needed(tier)] \
			if tier > 0 else tr("UI_MAX_TIER")
		(_buttons[key] as Button).disabled = not SaveManager.can_level_track(key)


## Name | "Lv 3" | "Unlocks T3 at Lv 6" | [+ Level]
func _make_row(key: String) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var name_label: Label = _make_label(Progression.display_name(key), 18)
	name_label.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	row.add_child(name_label)
	var level_label: Label = _make_label("", 18)
	level_label.custom_minimum_size = Vector2(LEVEL_WIDTH, 0)
	row.add_child(level_label)
	var hint_label: Label = _make_label("", 14)
	hint_label.custom_minimum_size = Vector2(HINT_WIDTH, 0)
	hint_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	row.add_child(hint_label)
	var button: Button = Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.text = tr("UI_LEVEL_UP_BUTTON")
	button.custom_minimum_size = Vector2(110, 34)
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(_level_up.bind(key))
	row.add_child(button)
	_level_labels[key] = level_label
	_hint_labels[key] = hint_label
	_buttons[key] = button
	return row


func _make_header(text: String) -> Label:
	var label: Label = _make_label(text, 22)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	return label


func _make_label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label
