class_name HeroCard
extends Control
## A hero's card (Dragon's Crown-style): silhouette, name, role, stats, playstyle, and
## "Play as ...". Shown beside the hero in camp, on the side away from them.
## Choosing mode (game start, nobody played yet): no Back; left/right browse the other heroes.

signal confirmed(character: CharacterData)
signal closed
signal browse(step: int) ## -1 = previous hero, +1 = next (choosing mode only).

const MARGIN: int = 40
const SILHOUETTE_SIZE: Vector2 = Vector2(44, 90) ## At body_scale 1.

var _character: CharacterData
var _choosing: bool = false

@onready var card: PanelContainer = %Card
@onready var header_label: Label = %HeaderLabel
@onready var silhouette: ColorRect = %Silhouette
@onready var name_label: Label = %NameLabel
@onready var role_label: Label = %RoleLabel
@onready var stats_label: Label = %StatsLabel
@onready var passive_label: Label = %PassiveLabel
@onready var description_label: Label = %DescriptionLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var back_button: Button = %BackButton


func _ready() -> void:
	confirm_button.pressed.connect(func() -> void: confirmed.emit(_character))
	back_button.pressed.connect(closed.emit)


## on_right: which screen side the card sits on. choosing: game-start mode (see class doc).
func show_character(character: CharacterData, on_right: bool, choosing: bool) -> void:
	_character = character
	_choosing = choosing
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT if on_right else Control.PRESET_CENTER_LEFT,
		Control.PRESET_MODE_MINSIZE, MARGIN)
	header_label.text = tr("UI_CHOOSE_HERO_HINT")
	header_label.visible = choosing
	back_button.visible = not choosing
	# Placeholder portrait: the hero's proportions, so cards differ by shape, not just color.
	silhouette.custom_minimum_size = SILHOUETTE_SIZE * Vector2(character.body_scale.x, character.body_scale.y)
	silhouette.color = character.color
	name_label.text = tr(character.name_key)
	role_label.text = tr(character.role_key)
	stats_label.text = "\n".join([
		"%s  %d" % [tr("STAT_MAX_HEALTH"), character.max_health],
		"%s  %d" % [tr("STAT_ATTACK"), character.attack_power],
		"%s  %d" % [tr("STAT_DEFENSE"), character.defense],
		"%s  %.1f" % [tr("STAT_SPEED"), character.move_speed],
		"%s  %d   %s  %d" % [tr("STAT_STAMINA"), roundi(character.max_stamina), tr("STAT_MANA"), roundi(character.max_mana)],
	])
	var skill_names: Array[String] = []
	for skill: SkillData in character.signature_skills:
		skill_names.append(tr(skill.name_key))
	var lines: Array[String] = [tr("UI_SKILLS_ROW") % ", ".join(skill_names)]
	if character.basic_attack:
		lines.append(tr("UI_BASIC_RANGED") % tr(character.basic_attack.name_key))
	if character.passive:
		lines.append(tr("UI_PASSIVE_ROW") % [tr(character.passive.name_key), character.passive.describe()])
	passive_label.text = "\n".join(lines)
	description_label.text = tr(character.description_key)
	confirm_button.text = tr("UI_PLAY_AS") % tr(character.name_key)
	confirm_button.grab_focus()


# _input, not _unhandled_input: the focused Confirm button would swallow left/right otherwise.
func _input(event: InputEvent) -> void:
	if _choosing:
		if event.is_action_pressed("ui_left"):
			get_viewport().set_input_as_handled()
			browse.emit(-1)
		elif event.is_action_pressed("ui_right"):
			get_viewport().set_input_as_handled()
			browse.emit(1)
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
