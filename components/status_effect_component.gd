class_name StatusEffectComponent
extends Node3D
## Elemental reactions on an enemy. Burn: damage over time. Chill: slow, enough stacks = Freeze.
## Poison: stacking damage over time. Shows them above the enemy as symbol + text, never color alone.
## HurtboxComponent asks it for weaknesses and reports element hits; the owner reads speed_multiplier().

const TICK: float = 0.5 ## Seconds between damage-over-time hits.
const BURN_TIME: float = 3.0
const BURN_FRACTION: float = 0.4 ## Total burn damage, as a part of the hit that lit it.
const POISON_TIME: float = 4.0
const POISON_MAX_STACKS: int = 5
const POISON_FRACTION: float = 0.08 ## Damage per second per stack, as a part of the hit.
const CHILL_TIME: float = 3.0
const CHILL_SLOW: float = 0.2 ## Speed lost per stack. Resisting ice weakens it.
const CHILL_TO_FREEZE: int = 3
const FREEZE_TIME: float = 1.5
const FREEZE_IMMUNE_TIME: float = 3.0 ## After thawing, so fast attacks can't freeze-lock an enemy.
const POPUP_COOLDOWN: float = 0.5
const POPUP_RISE: float = 1.0
const POPUP_LINE_HEIGHT: float = 0.5 ## Starts above the status lines already showing.
const POPUP_TIME: float = 0.7

@export var health: HealthComponent
@export var label_height: float = 2.0 ## Above the enemy's feet.

var data: EnemyData ## Set by the owner: weaknesses and whether it can be frozen.

var _burn_left: float = 0.0
var _burn_dps: float = 0.0
var _poison_left: float = 0.0
var _poison_dps: float = 0.0
var _poison_stacks: int = 0
var _chill_left: float = 0.0
var _chill_stacks: int = 0
var _frozen_left: float = 0.0
var _freeze_immune_left: float = 0.0
var _dot_bank: float = 0.0 ## Damage owed, so small numbers still add up to the exact total.
var _tick_left: float = TICK
var _popup_cooldown_left: float = 0.0
var _label: Label3D


func _ready() -> void:
	_label = _make_label()
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM # New lines grow up, off the enemy.
	_label.position.y = label_height
	add_child(_label)
	if health:
		health.died.connect(clear)


func _physics_process(delta: float) -> void:
	if health == null or health.is_dead:
		return
	_popup_cooldown_left = maxf(_popup_cooldown_left - delta, 0.0)
	_tick_timers(delta)
	_process_damage(delta)
	_refresh_label()


## Damage scale against this enemy: 1.5 = weak to it, 0.5 = resists it.
func element_multiplier(element: Element.Type) -> float:
	return data.element_multiplier(element) if data else 1.0


## Called by the hurtbox after an element hit landed. amount = the damage it really did.
func on_hit(element: Element.Type, amount: int) -> void:
	if element == Element.Type.PHYSICAL or health == null or health.is_dead:
		return
	_show_weakness_popup(element)
	match element:
		Element.Type.FIRE:
			_burn_dps = maxf(_burn_dps if _burn_left > 0.0 else 0.0, amount * BURN_FRACTION / BURN_TIME)
			_burn_left = BURN_TIME
		Element.Type.POISON:
			_poison_dps = maxf(_poison_dps if _poison_stacks > 0 else 0.0, amount * POISON_FRACTION)
			_poison_stacks = mini(_poison_stacks + 1, POISON_MAX_STACKS)
			_poison_left = POISON_TIME
		Element.Type.ICE:
			_add_chill()


func is_frozen() -> bool:
	return _frozen_left > 0.0


## 1 = full speed, 0 = frozen.
func speed_multiplier() -> float:
	if is_frozen():
		return 0.0
	return 1.0 - CHILL_SLOW * _chill_stacks * minf(element_multiplier(Element.Type.ICE), 1.0)


## Ends every status (death, or removed from the arena so it can't die later and earn a kill).
func clear() -> void:
	_burn_left = 0.0
	_poison_left = 0.0
	_poison_stacks = 0
	_chill_left = 0.0
	_chill_stacks = 0
	_frozen_left = 0.0
	_dot_bank = 0.0
	_refresh_label()


func _add_chill() -> void:
	if is_frozen():
		return
	_chill_left = CHILL_TIME
	_chill_stacks += 1
	if _chill_stacks < CHILL_TO_FREEZE:
		return
	if data and not data.can_be_frozen or _freeze_immune_left > 0.0:
		_chill_stacks = CHILL_TO_FREEZE - 1
		return
	_chill_stacks = 0
	_chill_left = 0.0
	_frozen_left = FREEZE_TIME
	_freeze_immune_left = FREEZE_TIME + FREEZE_IMMUNE_TIME


func _tick_timers(delta: float) -> void:
	_burn_left = maxf(_burn_left - delta, 0.0)
	_frozen_left = maxf(_frozen_left - delta, 0.0)
	_freeze_immune_left = maxf(_freeze_immune_left - delta, 0.0)
	_poison_left = maxf(_poison_left - delta, 0.0)
	if _poison_left == 0.0:
		_poison_stacks = 0
	_chill_left = maxf(_chill_left - delta, 0.0)
	if _chill_left == 0.0:
		_chill_stacks = 0


func _process_damage(delta: float) -> void:
	var dps: float = _poison_dps * _poison_stacks
	if _burn_left > 0.0:
		dps += _burn_dps
	_dot_bank += dps * delta
	_tick_left -= delta
	var amount: int = 0
	if dps == 0.0:
		amount = roundi(_dot_bank) # Everything ran out: pay what's left so totals stay exact.
		_dot_bank = 0.0
	elif _tick_left <= 0.0:
		amount = int(_dot_bank)
		_dot_bank -= amount
		_tick_left = TICK
	health.take_damage(amount)


func _refresh_label() -> void:
	var lines: Array[String] = []
	if is_frozen():
		lines.append(tr("STATUS_FROZEN"))
	elif _chill_stacks > 0:
		lines.append(tr("STATUS_CHILL") % _chill_stacks)
	if _burn_left > 0.0:
		lines.append(tr("STATUS_BURN"))
	if _poison_stacks > 0:
		lines.append(tr("STATUS_POISON") % _poison_stacks)
	_label.text = "\n".join(lines)


func _show_weakness_popup(element: Element.Type) -> void:
	var multiplier: float = element_multiplier(element)
	if multiplier == 1.0 or _popup_cooldown_left > 0.0:
		return
	_popup_cooldown_left = POPUP_COOLDOWN
	var popup: Label3D = _make_label()
	popup.text = tr("POPUP_WEAK") if multiplier > 1.0 else tr("POPUP_RESIST")
	# Lives in the world, not on the enemy, so it outlasts the killing blow.
	get_parent().get_parent().add_child(popup)
	var status_lines: int = _label.text.count("\n") + 1 if _label.text != "" else 0
	popup.global_position = _label.global_position + Vector3.UP * POPUP_LINE_HEIGHT * status_lines
	var tween: Tween = popup.create_tween().set_parallel()
	tween.tween_property(popup, "position:y", popup.position.y + POPUP_RISE, POPUP_TIME)
	tween.tween_property(popup, "transparency", 1.0, POPUP_TIME)
	tween.chain().tween_callback(popup.queue_free)


func _make_label() -> Label3D:
	var label: Label3D = Label3D.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.pixel_size = 0.015
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 24
	label.outline_size = 8
	return label
