class_name ChargerEnemy
extends Enemy
## Lines up and charges in a straight line (Tusker).
## IDLE -> APPROACH -> WINDUP (paws the ground; an arrow grows along the charge line) -> CHARGE
## -> RECOVER, or STUNNED for stun_time if it crashed into a wall or rock (the punish window).
## While charging it passes through heroes and other enemies: its ChargeHitbox does the damage.

enum State { IDLE, APPROACH, WINDUP, CHARGE, STUNNED, RECOVER }

const WORLD_ONLY_MASK: int = 1 ## Physics layer 1: walls, rocks, trees.
const CHARGE_KNOCKBACK: float = 12.0
const PAW_LEAN: float = 0.3
const PAW_STEPS: int = 3
const STUN_SWAY: float = 0.25

var state: State = State.IDLE

var _state_time: float = 0.0
var _charge_dir: Vector3 = Vector3.FORWARD
var _charged: float = 0.0
var _normal_mask: int = 0

@onready var charge_hitbox: HitboxComponent = $Visual/ChargeHitbox
@onready var arrow: Node3D = $ChargeArrow
@onready var arrow_shaft: Node3D = $ChargeArrow/Shaft
@onready var arrow_head: Node3D = $ChargeArrow/Head
@onready var stun_label: Label3D = $StunLabel


func _ready() -> void:
	super._ready()
	_normal_mask = collision_mask
	charge_hitbox.active = false
	charge_hitbox.knockback = CHARGE_KNOCKBACK
	# The arrow is exactly as long as the charge.
	arrow_shaft.scale.z = data.charge_distance
	arrow_shaft.position.z = -data.charge_distance * 0.5
	arrow_head.position.z = -data.charge_distance
	arrow.visible = false
	stun_label.text = tr("STATUS_STUNNED")
	stun_label.visible = false


func _behave(delta: float) -> void:
	_state_time += delta
	match state:
		State.IDLE:
			stand_still()
			target = find_nearest_player()
			if target and (hunt_from_start or flat_distance_to(target) <= data.detection_range):
				_change_state(State.APPROACH)
		State.APPROACH:
			if not refresh_target():
				_change_state(State.IDLE)
			elif flat_distance_to(target) <= data.attack_range:
				_change_state(State.WINDUP)
			else:
				walk(flat_direction_to(target))
		State.WINDUP:
			stand_still()
			if _state_time >= data.attack_windup:
				_change_state(State.CHARGE)
		State.CHARGE:
			var speed: float = data.charge_speed * status.speed_multiplier()
			velocity.x = _charge_dir.x * speed
			velocity.z = _charge_dir.z * speed
			_charged += speed * delta
			if _charged >= data.charge_distance:
				_change_state(State.RECOVER)
		State.STUNNED:
			stand_still()
			if _state_time >= data.stun_time:
				_change_state(State.APPROACH)
		State.RECOVER:
			stand_still()
			if _state_time >= data.attack_recovery:
				_change_state(State.APPROACH)


func _after_move() -> void:
	if state != State.CHARGE:
		return
	if is_on_wall():
		_change_state(State.STUNNED)
	elif status.is_frozen():
		_change_state(State.RECOVER) # Frozen mid-charge: the charge is over.


func _change_state(new_state: State) -> void:
	if state == State.CHARGE:
		_end_charge()
	if state == State.STUNNED:
		stun_label.visible = false
		stop_tween() # Stops the looping sway.
		visual.rotation = Vector3(0.0, visual.rotation.y, 0.0)
	state = new_state
	_state_time = 0.0
	match new_state:
		State.WINDUP:
			_start_windup()
		State.CHARGE:
			_start_charge()
		State.STUNNED:
			stun_label.visible = true
			var sway: Tween = restart_tween().set_loops()
			sway.tween_property(visual, "rotation:z", STUN_SWAY, 0.25)
			sway.tween_property(visual, "rotation:z", -STUN_SWAY, 0.25)
		State.RECOVER:
			animate_lean(0.0, 0.2)


## Direction locks now: the arrow shows exactly where it will go, so a sidestep dodges it.
func _start_windup() -> void:
	stand_still()
	_charge_dir = flat_direction_to(target) if is_target_valid() else -visual.global_basis.z
	face(_charge_dir)
	arrow.rotation.y = visual.rotation.y
	arrow.scale = Vector3(1.0, 1.0, 0.05)
	arrow.visible = true
	create_tween().tween_property(arrow, "scale:z", 1.0, data.attack_windup)
	# Pawing the ground: a few quick dips while leaning back.
	var paw: Tween = restart_tween()
	var step: float = data.attack_windup / (PAW_STEPS * 2)
	for i: int in PAW_STEPS:
		paw.tween_property(visual, "rotation:x", LEAN_BACK, step)
		paw.tween_property(visual, "rotation:x", PAW_LEAN, step)


func _start_charge() -> void:
	_charged = 0.0
	arrow.visible = false
	collision_mask = WORLD_ONLY_MASK
	charge_hitbox.damage = stats.get_attack_power()
	charge_hitbox.element = Element.Type.PHYSICAL
	charge_hitbox.active = true
	animate_lean(LEAN_FORWARD, 0.08)


func _end_charge() -> void:
	collision_mask = _normal_mask
	charge_hitbox.active = false
	stand_still()


func _stop_attacking() -> void:
	charge_hitbox.active = false
	arrow.visible = false
	stun_label.visible = false
