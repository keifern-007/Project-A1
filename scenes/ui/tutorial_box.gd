class_name TutorialBox
extends Control
## The tutorial's on-screen teacher: the current lesson at the top of the screen, then a guide to
## the camp's stations with a button back to camp. Only exists during the tutorial.

signal guide_closed

@onready var lesson_panel: PanelContainer = %LessonPanel
@onready var step_label: Label = %StepLabel
@onready var text_label: Label = %TextLabel
@onready var tip_label: Label = %TipLabel
@onready var guide_panel: Control = %GuidePanel
@onready var camp_button: Button = %CampButton


func _ready() -> void:
	guide_panel.hide()
	camp_button.pressed.connect(guide_closed.emit)


func show_step(number: int, total: int, text: String, tip: String) -> void:
	step_label.text = tr("TUT_STEP") % [number, total]
	text_label.text = text
	tip_label.text = tip


func show_guide() -> void:
	lesson_panel.hide()
	guide_panel.show()
	camp_button.grab_focus()
