extends Control
## The Mission Board panel (opened from the camp): pick a map, an objective and a difficulty,
## then start the run.
## Remembers the last choice (GameState keeps it).

signal closed

const RUN_SCENE: String = "res://scenes/main/retro_view.tscn"
const BUTTON_FONT_SIZE: int = 20
const BUTTON_SIZE: Vector2 = Vector2(280, 38) ## All the objectives and modes must fit at 1280×720.

@export var maps: Array[MapData] = []
@export var objectives: Array[ObjectiveData] = []
## First entry is the default (Normal). Harder ones are optional challenges.
@export var challenges: Array[ChallengeData] = []

var _map: MapData
var _objective: ObjectiveData
var _challenge: ChallengeData
var _objective_buttons: Array[Button] = []
var _abandon_button: Button
var _abandon_armed: bool = false

@onready var map_list: VBoxContainer = %MapList
@onready var objective_list: VBoxContainer = %ObjectiveList
@onready var challenge_list: VBoxContainer = %ChallengeList
@onready var details: Label = %Details
@onready var start_button: Button = %StartButton
@onready var back_button: Button = %BackButton


func _ready() -> void:
	var map_buttons: Array[Button] = _fill_list(map_list, maps, _select_map)
	_objective_buttons = _fill_list(objective_list, objectives, _select_objective)
	var challenge_buttons: Array[Button] = _fill_list(challenge_list, challenges, _select_challenge)
	start_button.pressed.connect(_start)
	back_button.pressed.connect(closed.emit)
	_preselect(map_buttons, maps, GameState.map, _select_map)
	_preselect(_objective_buttons, objectives, GameState.objective, _select_objective)
	_preselect(challenge_buttons, challenges, GameState.challenge, _select_challenge)
	_refresh_objectives()
	if not _objective_buttons.is_empty():
		_objective_buttons[0].grab_focus()


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
		button.custom_minimum_size = BUTTON_SIZE
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
	_refresh_objectives()
	_update_details()


## Shows only the objectives this map offers. If the selected one just disappeared
## (a boss from another map), selects the first one still listed.
func _refresh_objectives() -> void:
	var first_available: int = -1
	for i: int in objectives.size():
		var available: bool = objectives[i].available_on(_map)
		_objective_buttons[i].visible = available
		if available and first_available < 0:
			first_available = i
	if _objective != null and not _objective.available_on(_map) and first_available >= 0:
		_objective_buttons[first_available].button_pressed = true
		_select_objective(objectives[first_available])


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
	_refresh_abandon()
	var saved: ModeRun = _saved_run()
	start_button.text = "UI_CONTINUE_RUN" if saved else "UI_START"
	if saved: # The run already chose its hero and difficulty; nothing here changes them.
		start_button.disabled = false
		details.text = _saved_run_text(saved)
		return
	# Modes that travel between maps don't use the selected map, so a locked one can't block them.
	var multi_step: bool = _objective.is_multi_step()
	var locked_rank: int = maxi(0 if multi_step else _map.required_rank, maxi(_objective.required_rank, _challenge.required_rank))
	start_button.disabled = locked_rank > SaveManager.get_rank()
	# The scouting report comes first: it's what you need before leaving camp, so it must never need scrolling.
	var report: String = ScoutReport.text(_objective, SaveManager.get_character())
	var best: String = RunSummary.best_line(_objective)
	details.text = "%s%s  —  %s\n%s%s%s\n%s" % ["" if multi_step else tr(_map.name_key) + "  —  ", tr(_objective.name_key), tr(_challenge.name_key),
		report + "\n\n" if report != "" else "",
		"" if multi_step else tr(_map.description_key) + "\n",
		tr(_objective.description_key), _challenge.describe()]
	if best != "":
		details.text += "\n" + best
	if start_button.disabled:
		details.text += "\n" + tr("UI_RANK_NEEDED") % [locked_rank, SaveManager.get_rank()]


## The Classic run waiting to be resumed, if Classic is what's selected.
func _saved_run() -> ModeRun:
	if _objective == null or _objective.type != ObjectiveData.Type.CLASSIC:
		return null
	return ModeRun.load_saved(_objective, _map)


func _saved_run_text(run: ModeRun) -> String:
	var hero: CharacterData = CharacterRegistry.get_by_id(run.character_id)
	var difficulty: String = tr(run.challenge.name_key) if run.challenge else ""
	var hp_text: String = tr("UI_FULL_HP") if run.hp < 0 else str(run.hp)
	return "%s\n%s\n%s" % [tr("UI_SAVED_RUN") % [tr(hero.name_key), run.progress_text(), difficulty, hp_text, run.level],
		tr("UI_SAVED_RUN_NOTE"), tr(_objective.description_key)]


## Only there while a saved run is. Takes two presses, like leaving a mission.
func _refresh_abandon() -> void:
	if _abandon_button == null:
		_abandon_button = Button.new()
		_abandon_button.custom_minimum_size = Vector2(240, 48)
		_abandon_button.add_theme_font_size_override("font_size", 22)
		_abandon_button.pressed.connect(_on_abandon_pressed)
		start_button.get_parent().add_child(_abandon_button)
		start_button.get_parent().move_child(_abandon_button, start_button.get_index() + 1)
		_abandon_button.focus_exited.connect(func() -> void:
			_abandon_armed = false
			_abandon_button.text = "UI_ABANDON_RUN")
	_abandon_armed = false
	_abandon_button.text = "UI_ABANDON_RUN"
	_abandon_button.visible = _saved_run() != null


## Abandoning counts like leaving any mission: you keep what you collected, and it isn't a win.
func _on_abandon_pressed() -> void:
	if not _abandon_armed:
		_abandon_armed = true
		_abandon_button.text = "UI_ABANDON_CONFIRM"
		return
	var saved: ModeRun = _saved_run()
	SaveManager.profile["classic_run"] = {}
	SaveManager.commit_run(saved.rewards, false)
	_update_details()
	start_button.grab_focus()


func _start() -> void:
	GameState.map = _map
	GameState.objective = _objective
	GameState.challenge = _challenge
	GameState.mode_run = null
	if _objective.is_multi_step():
		GameState.mode_run = _saved_run()
		if GameState.mode_run: # Back to the hero who started this run.
			var hero: CharacterData = CharacterRegistry.get_by_id(GameState.mode_run.character_id)
			SaveManager.select_character(hero)
			GameState.character = hero
		else:
			GameState.mode_run = ModeRun.create(_objective, _map)
	get_tree().change_scene_to_file(RUN_SCENE)
