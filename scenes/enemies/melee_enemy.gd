class_name MeleeEnemy
extends Enemy
## Walks at the nearest player and hits them (Goblin). A small state machine:
## IDLE (wait for a player in range) -> CHASE -> ATTACK (wind-up, swing, recover) -> CHASE ... -> DEAD
## Everything shared (stats, statuses, knockback, death) lives in Enemy.

enum State { IDLE, CHASE, ATTACK, DEAD }

var state: State = State.IDLE

var _state_time: float = 0.0
var _has_swung: bool = false

@onready var melee: MeleeAttackComponent = $MeleeAttack


func _behave(delta: float) -> void:
	_state_time += delta
	match state:
		State.IDLE:
			_process_idle()
		State.CHASE:
			_process_chase()
		State.ATTACK:
			_process_attack()


func _change_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	if new_state == State.ATTACK:
		_has_swung = false
		stand_still()
		animate_lean(LEAN_BACK, data.attack_windup)


func _process_idle() -> void:
	stand_still()
	target = find_nearest_player()
	if target and (hunt_from_start or flat_distance_to(target) <= data.detection_range):
		_change_state(State.CHASE)


func _process_chase() -> void:
	if not refresh_target():
		_change_state(State.IDLE)
		return
	if flat_distance_to(target) <= data.attack_range:
		_change_state(State.ATTACK)
		return
	walk(flat_direction_to(target))


func _process_attack() -> void:
	if not _has_swung and _state_time >= data.attack_windup:
		_has_swung = true
		var dir: Vector3 = flat_direction_to(target) if is_target_valid() else -visual.global_basis.z
		face(dir)
		melee.attack(dir)
		animate_lean(LEAN_FORWARD, 0.05)
		_tween.tween_property(visual, "rotation:x", 0.0, data.attack_recovery * 0.5)
	elif _has_swung and _state_time >= data.attack_windup + data.attack_recovery:
		_change_state(State.CHASE)


func _stop_attacking() -> void:
	state = State.DEAD
	melee.hitbox.active = false
