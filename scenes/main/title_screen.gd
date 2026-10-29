extends Control
## The first screen: Start (into the camp, where you pick your hero) or Quit.

const HUB_SCENE: String = "res://scenes/main/hub.tscn"

@onready var start_button: Button = %StartButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	start_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(HUB_SCENE))
	quit_button.pressed.connect(get_tree().quit)
	start_button.grab_focus()
