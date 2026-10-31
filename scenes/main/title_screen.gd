extends Control
## The first screen: Start (into the camp, where you pick your hero), Options or Quit.

const HUB_SCENE: String = "res://scenes/main/hub.tscn"
const OPTIONS_PANEL: PackedScene = preload("res://scenes/ui/options_panel.tscn")

var _options: OptionsPanel = null

@onready var center: Control = $Center
@onready var start_button: Button = %StartButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	start_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(HUB_SCENE))
	options_button.pressed.connect(_open_options)
	quit_button.pressed.connect(get_tree().quit)
	start_button.grab_focus()


func _open_options() -> void:
	_options = OPTIONS_PANEL.instantiate()
	_options.closed.connect(_close_options)
	add_child(_options)
	center.hide()


func _close_options() -> void:
	_options.queue_free()
	_options = null
	center.show()
	options_button.grab_focus()
