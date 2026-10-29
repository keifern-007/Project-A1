class_name SkillSlot
extends PanelContainer
## One skill box on the HUD: key, name, cooldown bar and seconds left. Also used for the consumable.
## Cooling down = dimmed + bar + number; can't pay = dimmed + "No mana", so it never relies on color.

var _cooldown: float = 0.0

@onready var key_label: Label = %KeyLabel
@onready var name_label: Label = %NameLabel
@onready var cooldown_bar: ProgressBar = %CooldownBar
@onready var cooldown_label: Label = %CooldownLabel


## cost_text: e.g. "25 MP" shown next to the key ("" = free).
func setup(title: String, action: StringName, cooldown: float, cost_text: String = "") -> void:
	_cooldown = cooldown
	set_title(title)
	key_label.text = "[%s]" % InputHints.key_for(action)
	if cost_text != "":
		key_label.text += "  " + cost_text
	update_cooldown(0.0)


func set_title(title: String) -> void:
	name_label.text = title


## blocked_text: shown when it's ready but can't be paid for (e.g. "No mana"); "" = can pay.
func update_cooldown(seconds_left: float, blocked_text: String = "") -> void:
	var cooling: bool = seconds_left > 0.0
	cooldown_bar.value = seconds_left / _cooldown if _cooldown > 0.0 else 0.0
	if cooling:
		cooldown_label.text = "%.1f" % seconds_left
	else:
		cooldown_label.text = blocked_text if blocked_text != "" else tr("HUD_READY")
	modulate.a = 0.55 if cooling or blocked_text != "" else 1.0


## Nothing left to use (consumable ran out): dimmed and says so in words.
func show_empty() -> void:
	cooldown_bar.value = 0.0
	cooldown_label.text = tr("HUD_EMPTY")
	modulate.a = 0.4
