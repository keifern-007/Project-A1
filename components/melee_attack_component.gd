class_name MeleeAttackComponent
extends Node3D
## Swings a hitbox in front of its owner. Expects a HitboxComponent and a SwingVisual child.
## Reusable for melee enemies later — just put the hitbox on the "hits_player" layer.

signal attacked

## Optional. Damage = attack_power × damage_multiplier.
@export var stats: StatsComponent
@export var damage_multiplier: float = 1.0
@export var active_time: float = 0.12 ## How long the hitbox is live.
@export var cooldown: float = 0.35

var _cooldown_left: float = 0.0
var _active_left: float = 0.0

@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var swing_visual: Node3D = $SwingVisual


func _ready() -> void:
	_set_swinging(false)


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _active_left > 0.0:
		_active_left = maxf(_active_left - delta, 0.0)
		if _active_left == 0.0:
			_set_swinging(false)


func can_attack() -> bool:
	return _cooldown_left == 0.0


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
