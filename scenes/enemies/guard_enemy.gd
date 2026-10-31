class_name GuardEnemy
extends Enemy
## Advances behind a big shield (Shieldback). Hits from the front (within guard_angle_degrees) only
## do guard_multiplier damage ('Blocked!'); it turns slowly, so flanking works. A heavy hit
## (HitboxComponent.guard_break: big weapons) knocks the shield aside: guard_break_time of full
## damage while it staggers. IDLE -> CHASE -> WINDUP (plants the shield) -> SHOVE (short lunge) -> RECOVER.

enum State { IDLE, CHASE, WINDUP, SHOVE, RECOVER, STAGGER }

const SHOVE_SPEED: float = 6.0
const SHOVE_TIME: float = 0.25
const ATTACK_FACING: float = 0.9 ## Dot product: only shoves at heroes in front of the shield.
const BLOCK_POPUP_TIME: float = 0.5
const SHIELD_PLANTED: float = -0.25 ## Shield pushed forward during the wind-up.
const SHIELD_KNOCKED: Vector3 = Vector3(0.0, 1.5, 0.6) ## Swung aside when the guard breaks.

var state: State = State.IDLE

var _state_time: float = 0.0
var _yaw: float = 0.0
var _block_popup_left: float = 0.0
var _shield_tween: Tween

@onready var shield: Node3D = $Visual/ShieldPivot
@onready var shove_hitbox: HitboxComponent = $Visual/ShoveHitbox
@onready var guard_label: Label3D = $GuardLabel
@onready var block_label: Label3D = $BlockLabel


func _ready() -> void:
	super._ready()
	hurtbox.hit_modifier = _guard_scale
	shove_hitbox.active = false
	guard_label.text = tr("STATUS_GUARD_BROKEN")
	guard_label.visible = false
	block_label.text = tr("POPUP_BLOCKED")
	block_label.visible = false
	_yaw = visual.rotation.y


func _physics_process(delta: float) -> void:
	if _block_popup_left > 0.0:
		_block_popup_left -= delta
		if _block_popup_left <= 0.0:
			block_label.visible = false
	super._physics_process(delta)


func _behave(delta: float) -> void:
	_state_time += delta
	match state:
		State.IDLE:
			stand_still()
			target = find_nearest_player()
			if target and (hunt_from_start or flat_distance_to(target) <= data.detection_range):
				_change_state(State.CHASE)
		State.CHASE:
			_process_chase(delta)
		State.WINDUP:
			stand_still()
			_turn_toward_target(delta * 0.5)
			if _state_time >= data.attack_windup:
				_change_state(State.SHOVE)
		State.SHOVE:
			velocity.x = _forward().x * SHOVE_SPEED
			velocity.z = _forward().z * SHOVE_SPEED
			if _state_time >= SHOVE_TIME:
				_change_state(State.RECOVER)
		State.RECOVER:
			stand_still()
			if _state_time >= data.attack_recovery:
				_change_state(State.CHASE)
		State.STAGGER:
			stand_still()
			if _state_time >= data.guard_break_time:
				_change_state(State.CHASE)


func _process_chase(delta: float) -> void:
	if not refresh_target():
		_change_state(State.IDLE)
		return
	_turn_toward_target(delta)
	var facing: float = _forward().dot(flat_direction_to(target))
	if flat_distance_to(target) <= data.attack_range:
		stand_still()
		if facing >= ATTACK_FACING:
			_change_state(State.WINDUP)
		return
	# Walks the way the shield faces, so its slow turning really matters.
	var speed: float = current_speed() * maxf(facing, 0.2)
	velocity.x = _forward().x * speed
	velocity.z = _forward().z * speed


func _change_state(new_state: State) -> void:
	if state == State.SHOVE:
		shove_hitbox.active = false
	if state == State.STAGGER:
		guard_label.visible = false
		_move_shield(Vector3.ZERO, 0.25)
	state = new_state
	_state_time = 0.0
	match new_state:
		State.WINDUP:
			animate_lean(LEAN_BACK * 0.5, data.attack_windup)
			_move_shield(Vector3(SHIELD_PLANTED, 0.0, 0.0), data.attack_windup)
		State.SHOVE:
			shove_hitbox.damage = stats.get_attack_power()
			shove_hitbox.active = true
			animate_lean(LEAN_FORWARD, 0.06)
		State.RECOVER:
			animate_lean(0.0, 0.3)
			_move_shield(Vector3.ZERO, 0.3)
		State.STAGGER:
			guard_label.visible = true
			block_label.visible = false
			_block_popup_left = 0.0
			animate_lean(LEAN_BACK, 0.15)
			_move_shield(SHIELD_KNOCKED, 0.15)


## The hurtbox asks this for every hit: blocked from the front, full damage otherwise.
func _guard_scale(hitbox: HitboxComponent) -> float:
	if dead or state == State.STAGGER:
		return 1.0
	var to_hit: Vector3 = hitbox.global_position - global_position
	to_hit.y = 0.0
	if to_hit.length() < 0.05:
		return 1.0
	if _forward().dot(to_hit.normalized()) < cos(deg_to_rad(data.guard_angle_degrees)):
		return 1.0 # Flanked.
	if hitbox.guard_break:
		_change_state.call_deferred(State.STAGGER)
		GameFeel.shake(0.25)
		return 1.0
	block_label.visible = true
	_block_popup_left = BLOCK_POPUP_TIME
	return data.guard_multiplier


func _turn_toward_target(delta: float) -> void:
	if not is_target_valid():
		return
	var dir: Vector3 = flat_direction_to(target)
	_yaw = rotate_toward(_yaw, atan2(-dir.x, -dir.z), data.turn_speed * status.speed_multiplier() * delta)
	visual.rotation.y = _yaw


func _forward() -> Vector3:
	return Vector3(-sin(_yaw), 0.0, -cos(_yaw))


func _move_shield(rotation_target: Vector3, duration: float) -> void:
	if _shield_tween:
		_shield_tween.kill()
	_shield_tween = create_tween()
	_shield_tween.tween_property(shield, "rotation", rotation_target, duration)


func _stop_attacking() -> void:
	shove_hitbox.active = false
	guard_label.visible = false
	block_label.visible = false
