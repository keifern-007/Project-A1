class_name HUD
extends Control
## In-run HUD: HP, run timer, wave, kills, skill and consumable cooldowns.
## Whoever owns the HUD calls bind_player(); the HUD never goes looking for the player itself.

const STAMINA_WARNING_TIME: float = 0.8 ## How long 'No stamina' shows after a refused attack/dodge.
const SKILL_SLOT_SCENE: PackedScene = preload("res://scenes/ui/skill_slot.tscn")

var _skill_caster: SkillCasterComponent
var _boosters: BoosterComponent
var _passives: PassiveComponent
var _slots: Array[SkillSlot] = []
var _consumables: ConsumableComponent
var _consumable_slot: SkillSlot
var _stamina: MeterComponent
var _stamina_warning_left: float = 0.0

@onready var crosshair: Label = %Crosshair
@onready var camera_hint: Label = %CameraHint
@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var stamina_label: Label = %StaminaLabel
@onready var mana_bar: ProgressBar = %ManaBar
@onready var mana_label: Label = %ManaLabel
@onready var cast_bar: ProgressBar = %CastBar
@onready var cast_label: Label = %CastLabel
@onready var timer_label: Label = %TimerLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var kills_label: Label = %KillsLabel
@onready var skill_row: HBoxContainer = %SkillRow
@onready var level_label: Label = %LevelLabel
@onready var xp_bar: ProgressBar = %XpBar
@onready var boost_label: Label = %BoostLabel
@onready var level_up_label: Label = %LevelUpLabel


func _ready() -> void:
	objective_label.text = ""
	camera_hint.text = tr("HUD_CAMERA_HINT") % InputHints.key_for("camera_toggle")
	EventBus.objective_progress.connect(_on_objective_progress)


func bind_player(player: Player) -> void:
	player.health.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health.current, player.health.max_health)

	player.stamina.changed.connect(_on_meter_changed.bind(stamina_bar, stamina_label, "HUD_STAMINA"))
	_stamina = player.stamina
	player.stamina_short.connect(func() -> void: _stamina_warning_left = STAMINA_WARNING_TIME)
	player.mana.changed.connect(_on_meter_changed.bind(mana_bar, mana_label, "HUD_MANA"))
	_on_meter_changed(player.stamina.current, player.stamina.max_value, stamina_bar, stamina_label, "HUD_STAMINA")
	_on_meter_changed(player.mana.current, player.mana.max_value, mana_bar, mana_label, "HUD_MANA")

	player.level.xp_changed.connect(_on_xp_changed)
	player.level.leveled_up.connect(_on_leveled_up)
	_on_xp_changed(player.level.xp, player.level.xp_to_next(), player.level.level)
	_boosters = player.boosters
	_passives = player.passives

	_skill_caster = player.skill_caster
	for child: Node in skill_row.get_children():
		child.queue_free()
	_slots.clear()
	for i: int in _skill_caster.skills.size():
		var slot: SkillSlot = SKILL_SLOT_SCENE.instantiate()
		skill_row.add_child(slot)
		var skill: SkillData = _skill_caster.skills[i]
		slot.setup(tr(skill.name_key), "skill_%d" % (i + 1), _skill_caster.cooldown_of(skill), _slot_info(skill))
		_slots.append(slot)

	_consumables = player.consumables
	_consumable_slot = null
	if _consumables.item:
		_consumable_slot = SKILL_SLOT_SCENE.instantiate()
		skill_row.add_child(_consumable_slot)
		_consumable_slot.setup("", "use_consumable", _consumables.item.use_cooldown)
		_consumables.changed.connect(_on_consumables_changed)
		_on_consumables_changed()


# Timer, kills and cooldowns change every frame anyway, so just read them.
func _process(delta: float) -> void:
	_update_stamina_warning(delta)
	crosshair.visible = Settings.camera_mode == Settings.CameraMode.OVER_THE_SHOULDER
	timer_label.text = format_time(GameState.run_time)
	kills_label.text = tr("HUD_KILLS") % GameState.kills
	var lines: Array[String] = []
	if _boosters and _boosters.active_boost:
		lines.append(tr("HUD_BOOST") % [tr(_boosters.active_boost.name_key), ceili(_boosters.time_left)])
	if _passives and _passives.status_text() != "":
		lines.append(_passives.status_text())
	boost_label.text = "\n".join(lines)
	if _skill_caster:
		for i: int in _slots.size():
			_slots[i].update_cooldown(_skill_caster.get_cooldown_left(i), _blocked_text(_skill_caster.skills[i]))
		cast_bar.visible = _skill_caster.is_casting() and _skill_caster.casting_skill() != _skill_caster.basic_attack
		if cast_bar.visible:
			cast_bar.value = _skill_caster.cast_progress()
			cast_label.text = tr("HUD_CASTING") % tr(_skill_caster.casting_skill().name_key)
	if _consumable_slot and _consumables.get_count() > 0:
		_consumable_slot.update_cooldown(_consumables.cooldown_left)


## "Moonleaf Draught x3"; at zero it stays visible, dimmed and marked "Empty".
func _on_consumables_changed() -> void:
	var count: int = _consumables.get_count()
	_consumable_slot.set_title("%s %s" % [tr(_consumables.item.name_key), tr("UI_COUNT_TAG") % count])
	if count == 0:
		_consumable_slot.show_empty()


## "25 MP" / "30 ST"; "" for free skills.
## Cost and element next to the skill's key, e.g. "25 MP  * Ice".
func _slot_info(skill: SkillData) -> String:
	var parts: Array[String] = []
	if skill.cost > 0.0:
		parts.append(_cost_text(skill))
	if skill.element != Element.Type.PHYSICAL:
		parts.append(tr(Element.name_key(skill.element)))
	return "  ".join(parts)


func _cost_text(skill: SkillData) -> String:
	if skill.cost <= 0.0:
		return ""
	return tr("HUD_COST_MANA" if skill.kind == SkillData.Kind.MAGIC else "HUD_COST_STAMINA") % roundi(skill.cost)


## "No mana" / "No stamina" when the skill can't be paid for right now; "" otherwise.
func _blocked_text(skill: SkillData) -> String:
	if _skill_caster.can_afford(skill):
		return ""
	return tr("HUD_NO_MANA" if skill.kind == SkillData.Kind.MAGIC else "HUD_NO_STAMINA")


## Text, not just the bar's color: 'Stamina 3/110 - No stamina' after a refused attack or dodge.
func _update_stamina_warning(delta: float) -> void:
	if _stamina_warning_left <= 0.0:
		return
	_stamina_warning_left = maxf(_stamina_warning_left - delta, 0.0)
	_on_meter_changed(_stamina.current, _stamina.max_value, stamina_bar, stamina_label, "HUD_STAMINA")


func _on_meter_changed(current: float, maximum: float, bar: ProgressBar, label: Label, key: String) -> void:
	bar.max_value = maxf(maximum, 1.0)
	bar.value = current
	label.text = tr(key) % [floori(current), roundi(maximum)]
	if bar == stamina_bar and _stamina_warning_left > 0.0:
		label.text += "  -  " + tr("HUD_NO_STAMINA")


func _on_health_changed(current: int, maximum: int) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_label.text = tr("HUD_HP") % [current, maximum]


func _on_xp_changed(xp: int, xp_needed: int, level: int) -> void:
	xp_bar.max_value = xp_needed
	xp_bar.value = xp
	level_label.text = tr("HUD_LEVEL") % level


# A gentle rise-and-fade, never a flash.
func _on_leveled_up(_level: int) -> void:
	level_up_label.show()
	level_up_label.modulate.a = 1.0
	level_up_label.position.y = level_up_label.get_parent_area_size().y * 0.5 - 160.0
	var tween: Tween = create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(level_up_label, "modulate:a", 0.0, 0.8)
	tween.parallel().tween_property(level_up_label, "position:y", level_up_label.position.y - 30.0, 0.8)
	tween.tween_callback(level_up_label.hide)


func _on_objective_progress(name_key: String, current: int, target: int) -> void:
	objective_label.text = "%s  %d/%d" % [tr(name_key), current, target]
	if GameState.challenge and GameState.challenge.is_harder():
		objective_label.text = "[%s]  %s" % [tr(GameState.challenge.name_key), objective_label.text]


## Seconds as mm:ss.
static func format_time(seconds: float) -> String:
	var total: int = floori(seconds)
	return "%02d:%02d" % [floori(total / 60.0), total % 60]
