class_name MeleeAttackComponent
extends Node3D
## Swings a hitbox in front of its owner. Expects a HitboxComponent and a SwingVisual child.
## Reusable for melee enemies later — just put the hitbox on the "hits_player" layer.

signal attacked
signal windup_started(duration: float)
signal windup_cancelled

## Optional. Damage = attack_power × damage_multiplier.
@export var stats: StatsComponent
@export var damage_multiplier: float = 1.0
@export var active_time: float = 0.12 ## How long the hitbox is live.
@export var cooldown: float = 0.35
@export var windup_time: float = 0.0 ## start_attack() waits this long before swinging.
@export var commit_time: float = 0.0 ## Seconds the owner stays locked in after the swing.

var _cooldown_left: float = 0.0
var _active_left: float = 0.0
var _windup_left: float = 0.0
var _windup_direction: Vector3 = Vector3.ZERO

@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var swing_visual: Node3D = $SwingVisual


func _ready() -> void:
	_set_swinging(false)


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if is_winding_up():
		_windup_left = maxf(_windup_left - delta, 0.0)
		if _windup_left == 0.0:
			attack(_windup_direction)
	if _active_left > 0.0:
		_active_left = maxf(_active_left - delta, 0.0)
		if _active_left == 0.0:
			_set_swinging(false)


func can_attack() -> bool:
	return _cooldown_left == 0.0


func is_winding_up() -> bool:
	return _windup_left > 0.0


## Winds up, then swings where the owner aims at the end. Returns true if it started.
func start_attack(direction: Vector3) -> bool:
	if is_winding_up() or not can_attack() or direction == Vector3.ZERO:
		return false
	if windup_time <= 0.0:
		return attack(direction)
	_windup_direction = direction
	_windup_left = windup_time
	windup_started.emit(windup_time)
	return true


func update_windup_direction(direction: Vector3) -> void:
	if direction != Vector3.ZERO:
		_windup_direction = direction


func cancel_windup() -> void:
	if is_winding_up():
		_windup_left = 0.0
		windup_cancelled.emit()


## Returns true if the swing actually started.
func attack(direction: Vector3) -> bool:
	if not can_attack() or direction == Vector3.ZERO:
		return false
	global_rotation.y = atan2(-direction.x, -direction.z)
	if stats:
		hitbox.damage = roundi(stats.get_attack_power() * damage_multiplier)
	_cooldown_left = cooldown
	_active_left = active_time
	_set_swinging(true)
	attacked.emit()
	return true


func _set_swinging(on: bool) -> void:
	hitbox.active = on
	swing_visual.visible = on
