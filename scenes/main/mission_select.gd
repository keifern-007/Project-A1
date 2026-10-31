extends Control
## The Mission Board panel (opened from the camp): pick a map, an objective and a difficulty,
## then start the run.
## Remembers the last choice (GameState keeps it).

signal closed

const RUN_SCENE: String = "res://scenes/main/retro_view.tscn"
const BUTTON_FONT_SIZE: int = 22

@export var maps: Array[MapData] = []
@export var objectives: Array[ObjectiveData] = []
## First entry is the default (Normal). Harder ones are optional challenges.
@export var challenges: Array[ChallengeData] = []

var _map: MapData
var _objective: ObjectiveData
var _challenge: ChallengeData

@onready var map_list: VBoxContainer = %MapList
@onready var objective_list: VBoxContainer = %ObjectiveList
@onready var challenge_list: VBoxContainer = %ChallengeList
@onready var details: Label = %Details
@onready var start_button: Button = %StartButton
@onready var back_button: Button = %BackButton


func _ready() -> void:
	var map_buttons: Array[Button] = _fill_list(map_list, maps, _select_map)
	var objective_buttons: Array[Button] = _fill_list(objective_list, objectives, _select_objective)
	var challenge_buttons: Array[Button] = _fill_list(challenge_list, challenges, _select_challenge)
	start_button.pressed.connect(_start)
	back_button.pressed.connect(closed.emit)
	_preselect(map_buttons, maps, GameState.map, _select_map)
	_preselect(objective_buttons, objectives, GameState.objective, _select_objective)
	_preselect(challenge_buttons, challenges, GameState.challenge, _select_challenge)
	if not objective_buttons.is_empty():
		objective_buttons[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


## One toggle button per entry; a ButtonGroup makes them behave like radio buttons.
func _fill_list(list: VBoxContainer, entries: Array, on_select: Callable) -> Array[Button]:
	var group: ButtonGroup = ButtonGroup.new()
	var buttons: Array[Button] = []
	for entry: Resource in entries:
		var button: Button = Button.new()
		var label: String = tr(entry.get("name_key"))
		var required_rank: int = entry.get("required_rank")
		if required_rank > SaveManager.get_rank():
			label += "   " + tr("UI_RANK_LOCKED") % required_rank
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.text = label
		# Selection gets a marker, not just a darker shade (never color alone).
		button.toggled.connect(func(on: bool) -> void: button.text = ("»  " if on else "") + label)
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(280, 52)
		button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
		button.pressed.connect(on_select.bind(entry))
		list.add_child(button)
		buttons.append(button)
	return buttons


func _preselect(buttons: Array[Button], entries: Array, previous: Resource, on_select: Callable) -> void:
	if entries.is_empty():
		return
	var index: int = maxi(entries.find(previous), 0)
	buttons[index].button_pressed = true
	on_select.call(entries[index])


func _select_map(map: MapData) -> void:
	_map = map
	_update_details()


func _select_objective(objective: ObjectiveData) -> void:
	_objective = objective
	_update_details()


func _select_challenge(challenge: ChallengeData) -> void:
	_challenge = challenge
	_update_details()


func _update_details() -> void:
	if _map == null or _objective == null or _challenge == null:
		details.text = ""
		start_button.disabled = true
		return
	var locked_rank: int = maxi(maxi(_map.required_rank, _objective.required_rank), _challenge.required_rank)
	start_button.disabled = locked_rank > SaveManager.get_rank()
	details.text = "%s  —  %s  —  %s\n%s\n%s\n%s" % [tr(_map.name_key), tr(_objective.name_key), tr(_challenge.name_key),
		tr(_map.description_key), tr(_objective.description_key), _challenge.describe()]
	if start_button.disabled:
		details.text += "\n" + tr("UI_RANK_NEEDED") % [locked_rank, SaveManager.get_rank()]


func _start() -> void:
	GameState.map = _map
	GameState.objective = _objective
	GameState.challenge = _challenge
	get_tree().change_scene_to_file(RUN_SCENE)
