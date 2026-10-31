class_name OptionsPanel
extends Control
## The small options screen, opened from the title screen, the camp and the pause menu.
## Every change applies and saves at once, so there is no Apply button.
## Rebinding, audio, languages, HUD and colorblind modes join in Phase 6.

signal closed

@onready var flashing_check: CheckButton = %FlashingCheck
@onready var shake_label: Label = %ShakeLabel
@onready var shake_slider: HSlider = %ShakeSlider
@onready var arachnophobia_check: CheckButton = %ArachnophobiaCheck
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var back_button: Button = %BackButton


func _ready() -> void:
	# Set the current values before connecting, so opening the panel doesn't save anything.
	flashing_check.button_pressed = Settings.reduce_flashing
	shake_slider.value = Settings.screen_shake
	arachnophobia_check.button_pressed = Settings.arachnophobia_mode
	fullscreen_check.button_pressed = Settings.fullscreen
	_update_shake_label()
	flashing_check.toggled.connect(_on_flashing_toggled)
	shake_slider.value_changed.connect(_on_shake_changed)
	arachnophobia_check.toggled.connect(_on_arachnophobia_toggled)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(closed.emit)
	flashing_check.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _on_flashing_toggled(on: bool) -> void:
	Settings.reduce_flashing = on
	Settings.save_settings()


func _on_shake_changed(value: float) -> void:
	Settings.screen_shake = value
	Settings.save_settings()
	_update_shake_label()


func _on_arachnophobia_toggled(on: bool) -> void:
	Settings.arachnophobia_mode = on
	Settings.save_settings()


func _on_fullscreen_toggled(on: bool) -> void:
	Settings.fullscreen = on
	Settings.save_settings()


func _update_shake_label() -> void:
	shake_label.text = tr("UI_OPT_SCREEN_SHAKE") % roundi(shake_slider.value * 100.0)
