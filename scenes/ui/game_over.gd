class_name GameOverScreen
extends Control
## The run's results: victory or defeat, stats, and what you earned.
## Shown when the run ends — every player down, or the objective complete. Runs while the game is paused (process_mode = Always).
## It only reports button presses; the game root decides what restart/quit actually do.

signal restart_requested
signal camp_requested
signal quit_requested

const REWARD_REVEAL_DELAY: float = 0.15 ## Between reward rows appearing.
const SWATCH_SIZE: Vector2 = Vector2(16, 16)
const MAX_REWARDS_HEIGHT: float = 240.0 ## Longer tallies scroll, so the buttons stay on screen.

@onready var title_label: Label = %Title
@onready var subtitle_label: Label = %Subtitle
@onready var stats_label: Label = %StatsLabel
@onready var rewards_scroll: ScrollContainer = %RewardsScroll
@onready var rewards_list: VBoxContainer = %RewardsList
@onready var restart_button: Button = %RestartButton
@onready var camp_button: Button = %CampButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	hide()
	restart_button.pressed.connect(restart_requested.emit)
	camp_button.pressed.connect(camp_requested.emit)
	quit_button.pressed.connect(quit_requested.emit)


## rewards: [{ "material": MaterialData, "amount": int, "owned": int (profile total) }, ...]
func show_results(victory: bool, run_time: float, kills: int, level: int, rewards: Array[Dictionary],
		xp_lines: Array[String] = [], left_mission: bool = false) -> void:
	# These labels auto-translate, so setting the key is enough.
	title_label.text = "UI_VICTORY" if victory else "UI_GAME_OVER"
	subtitle_label.text = "UI_VICTORY_SUB" if victory else "UI_GAME_OVER_SUB"
	if left_mission:
		title_label.text = "UI_LEFT_MISSION"
		subtitle_label.text = "UI_LEFT_MISSION_SUB"
	stats_label.text = tr("UI_RUN_STATS") % [HUD.format_time(run_time), kills, level]
	_fill_rewards(rewards, xp_lines)
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)
	# Focus lets keyboard (Enter) and gamepad (A) press it without a mouse.
	restart_button.grab_focus()


func _fill_rewards(rewards: Array[Dictionary], xp_lines: Array[String]) -> void:
	for child: Node in rewards_list.get_children():
		child.queue_free()
	if rewards.is_empty() and xp_lines.is_empty():
		rewards_list.add_child(_make_label(tr("UI_NO_REWARDS")))
		_fit_rewards_height()
		return
	var rows: Array[Control] = []
	for i: int in rewards.size():
		rows.append(_make_row(rewards[i]["material"], rewards[i]["amount"], rewards[i].get("owned", 0)))
	for line: String in xp_lines:
		rows.append(_make_label(line))
	for i: int in rows.size():
		rewards_list.add_child(rows[i])
		# Rows appear one after another, like a loot tally.
		rows[i].modulate.a = 0.0
		create_tween().tween_property(rows[i], "modulate:a", 1.0, 0.3).set_delay(0.4 + i * REWARD_REVEAL_DELAY)
	_fit_rewards_height()


# A ScrollContainer doesn't size to its content: as tall as the rows, up to the limit.
func _fit_rewards_height() -> void:
	rewards_scroll.custom_minimum_size.y = minf(rewards_list.get_combined_minimum_size().y, MAX_REWARDS_HEIGHT)


## Color swatch + name + amount (the name carries the meaning; the swatch is just a hint).
func _make_row(material: MaterialData, amount: int, owned: int) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var swatch: ColorRect = ColorRect.new()
	swatch.custom_minimum_size = SWATCH_SIZE
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.color = material.color if material else Color.WHITE
	row.add_child(swatch)
	var name_text: String = tr(material.name_key) if material else "?"
	var text: String = tr("UI_REWARD_ROW") % [name_text, amount]
	if owned > 0:
		text += "   " + tr("UI_REWARD_OWNED") % owned
	row.add_child(_make_label(text))
	return row


func _make_label(text: String) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label
