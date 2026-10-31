class_name SupportEnemy
extends Enemy
## Hangs back and protects its friends (Goblin Shaman). Harmless itself: the lesson is target priority.
## IDLE -> MOVE (keeps attack_range from you, runs if you get inside retreat_range) -> CAST (staff up;
## a tether shows which ally it picked) -> the ally is Warded -> RECOVER -> MOVE ...
## It picks the ally closest to you: the one you're about to hit.

enum State { IDLE, MOVE, CAST, RECOVER }

const STAFF_RAISED: float = -2.6
const RETREAT_SPEED: float = 0.9
const RETRY_DELAY: float = 1.5 ## After a cast is cut short (the ally died).

var state: State = State.IDLE

var _state_time: float = 0.0
var _cooldown_left: float = 0.0
var _ally: Enemy
var _arm_tween: Tween

@onready var arm: Node3D = $Visual/Arm
@onready var tether: MeshInstance3D = $Tether


func _ready() -> void:
	super._ready()
	tether.top_level = true
	tether.visible = false
	_cooldown_left = data.attack_cooldown * 0.5


func _behave(delta: float) -> void:
	_state_time += delta
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	match state:
		State.IDLE:
			stand_still()
			target = find_nearest_player()
			if target and (hunt_from_start or flat_distance_to(target) <= data.detection_range):
				_change_state(State.MOVE)
		State.MOVE:
			_process_move()
		State.CAST:
			_process_cast()
		State.RECOVER:
			stand_still()
			if _state_time >= data.attack_recovery:
				_change_state(State.MOVE)


func _process_move() -> void:
	if not refresh_target():
		_change_state(State.IDLE)
		return
	var distance: float = flat_distance_to(target)
	var to_target: Vector3 = flat_direction_to(target)
	if distance < data.retreat_range:
		walk(-to_target, RETREAT_SPEED)
		face(to_target)
	elif distance > data.attack_range:
		walk(to_target)
	else:
		stand_still()
		face(to_target)
	if _cooldown_left == 0.0:
		var ally: Enemy = _pick_ally()
		if ally:
			_ally = ally
			_change_state(State.CAST)


func _process_cast() -> void:
	stand_still()
	if not is_instance_valid(_ally) or _ally.dead:
		_cooldown_left = RETRY_DELAY
		_cancel_cast()
		_change_state(State.MOVE)
		return
	face(flat_direction_to(_ally))
	_update_tether()
	if _state_time >= data.attack_windup:
		_ally.apply_ward(data.ward_duration, data.ward_multiplier)
		_cooldown_left = data.attack_cooldown
		_cancel_cast()
		_change_state(State.RECOVER)


func _change_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	if new_state == State.CAST:
		stand_still()
		animate_lean(LEAN_BACK * 0.6, data.attack_windup)
		_swing_arm(STAFF_RAISED, data.attack_windup * 0.6)
		tether.visible = true
		_update_tether()


## The living ally nearest to the hero (it's the one about to be hit), within ward_range of us.
func _pick_ally() -> Enemy:
	var best: Enemy = null
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var ally: Enemy = node as Enemy
		if ally == null or ally == self or ally.dead or ally.is_warded():
			continue
		if flat_distance_to(ally) > data.ward_range:
			continue
		var to_hero: float = ally.flat_distance_to(target) if is_target_valid() else 0.0
		if to_hero < best_distance:
			best_distance = to_hero
			best = ally
	return best


## A thin beam from the staff to the chosen ally: shows who is about to be warded.
func _update_tether() -> void:
	var from: Vector3 = global_position + Vector3.UP * 1.4
	var to: Vector3 = _ally.global_position + Vector3.UP * 0.9
	var length: float = from.distance_to(to)
	if length < 0.1:
		return
	tether.global_position = (from + to) * 0.5
	tether.look_at(to, Vector3.UP)
	tether.scale = Vector3(1.0, 1.0, length)


func _cancel_cast() -> void:
	tether.visible = false
	_swing_arm(0.0, 0.2)
	animate_lean(0.0, 0.2)
	_ally = null


func _swing_arm(angle: float, duration: float) -> void:
	if _arm_tween:
		_arm_tween.kill()
	_arm_tween = create_tween()
	_arm_tween.tween_property(arm, "rotation:x", angle, duration)


func _stop_attacking() -> void:
	tether.visible = false
	if _arm_tween:
		_arm_tween.kill()
