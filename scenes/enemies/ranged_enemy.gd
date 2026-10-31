class_name RangedEnemy
extends Enemy
## Keeps its distance and lobs shots at the nearest player (Goblin Slinger).
## IDLE -> MOVE (back away if too close, approach if out of range) -> WINDUP (arm back, lean)
## -> throw a LobbedShot at where the player stands -> RECOVER -> MOVE ...
## It walks slower than heroes, so chasing it down works; that's the lesson.

enum State { IDLE, MOVE, WINDUP, RECOVER }

const ARM_RAISED: float = -2.4 ## Radians: the sling arm swung back over the shoulder.
const RETREAT_SPEED: float = 0.85 ## Backing away is a bit slower than walking.

@export var throw_height: float = 1.4 ## Where the shot leaves the hand.

var state: State = State.IDLE

var _state_time: float = 0.0
var _cooldown_left: float = 0.0
var _arm_tween: Tween

@onready var arm: Node3D = $Visual/Arm


func _behave(delta: float) -> void:
	_state_time += delta
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	match state:
		State.IDLE:
			_process_idle()
		State.MOVE:
			_process_move()
		State.WINDUP:
			_process_windup()
		State.RECOVER:
			stand_still()
			if _state_time >= data.attack_recovery:
				_change_state(State.MOVE)


func _change_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	if new_state == State.WINDUP:
		stand_still()
		animate_lean(LEAN_BACK, data.attack_windup)
		_swing_arm(ARM_RAISED, data.attack_windup)


func _process_idle() -> void:
	stand_still()
	target = find_nearest_player()
	if target and (hunt_from_start or flat_distance_to(target) <= data.detection_range):
		_change_state(State.MOVE)


func _process_move() -> void:
	if not refresh_target():
		_change_state(State.IDLE)
		return
	var distance: float = flat_distance_to(target)
	var to_target: Vector3 = flat_direction_to(target)
	if distance < data.retreat_range:
		walk(-to_target, RETREAT_SPEED)
		face(to_target) # Backs away facing you.
	elif distance > data.attack_range:
		walk(to_target)
	else:
		stand_still()
		face(to_target)
		if _cooldown_left == 0.0:
			_change_state(State.WINDUP)


func _process_windup() -> void:
	if is_target_valid():
		face(flat_direction_to(target))
	if _state_time < data.attack_windup:
		return
	if is_target_valid():
		_throw(target.global_position)
	_cooldown_left = data.attack_cooldown
	animate_lean(LEAN_FORWARD, 0.05)
	_tween.tween_property(visual, "rotation:x", 0.0, data.attack_recovery * 0.5)
	_swing_arm(0.0, 0.12)
	_change_state(State.RECOVER)


## Aimed at where the player stands right now: the ring shows it, moving away dodges it.
func _throw(at: Vector3) -> void:
	if data.projectile_scene == null:
		return
	var shot: LobbedShot = data.projectile_scene.instantiate()
	shot.setup(global_position + Vector3.UP * throw_height, at, stats.get_attack_power(),
		data.projectile_element, 4.0)
	get_parent().add_child(shot)


func _swing_arm(angle: float, duration: float) -> void:
	if _arm_tween:
		_arm_tween.kill()
	_arm_tween = create_tween()
	_arm_tween.tween_property(arm, "rotation:x", angle, duration)


func _stop_attacking() -> void:
	if _arm_tween:
		_arm_tween.kill()
