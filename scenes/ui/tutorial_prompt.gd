extends Control
## The Field Guide book stand in camp: asks if you want to play the tutorial, then starts it.

signal closed

const RUN_SCENE: String = "res://scenes/main/retro_view.tscn"
const TUTORIAL_MAP: MapData = preload("res://resources/maps/greybox.tres") ## Training Grounds.
const TUTORIAL: ObjectiveData = preload("res://resources/objectives/tutorial.tres")

@onready var play_button: Button = %PlayButton
@onready var not_now_button: Button = %NotNowButton


func _ready() -> void:
	play_button.pressed.connect(_play)
	not_now_button.pressed.connect(closed.emit)
	play_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _play() -> void:
	GameState.map = TUTORIAL_MAP
	GameState.objective = TUTORIAL
	GameState.challenge = null
	get_tree().change_scene_to_file(RUN_SCENE)
