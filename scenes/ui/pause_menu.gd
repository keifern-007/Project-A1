class_name PauseMenu
extends Control
## In-run pause: Resume, Options, Leave Mission. Runs while the game is paused (process_mode = Always).
## Leaving takes a second press, so a stray click can't end a run. The run scene decides what leaving does.

signal leave_requested

const OPTIONS_PANEL: PackedScene = preload("res://scenes/ui/options_panel.tscn")

var _options: OptionsPanel = null
var _leave_armed: bool = false

@onready var center: Control = $Center
@onready var resume_button: Button = %ResumeButton
@onready var options_button: Button = %OptionsButton
@onready var leave_button: Button = %LeaveButton


func _ready() -> void:
	hide()
	resume_button.pressed.connect(resume)
	options_button.pressed.connect(_open_options)
	leave_button.pressed.connect(_on_leave_pressed)
	leave_button.focus_exited.connect(_disarm_leave)


func _unhandled_input(event: InputEvent) -> void:
	if _options: # The options panel closes itself first.
		return
	if event.is_action_pressed("pause") or (visible and event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		if visible:
			resume()
		elif GameState.run_active: # Not during the death delay or on the results screen.
			pause()


func pause() -> void:
	GameFeel.cancel_hit_stop()
	get_tree().paused = true
	_disarm_leave()
	show()
	resume_button.grab_focus()


func resume() -> void:
	hide()
	get_tree().paused = false


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


func _on_leave_pressed() -> void:
	if _leave_armed:
		hide()
		leave_requested.emit()
		return
	_leave_armed = true
	leave_button.text = "UI_LEAVE_CONFIRM"


func _disarm_leave() -> void:
	_leave_armed = false
	leave_button.text = "UI_LEAVE_MISSION"
