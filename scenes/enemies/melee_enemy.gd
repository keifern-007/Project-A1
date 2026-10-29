class_name MeleeEnemy
extends CharacterBody3D
## Walks at the nearest player and hits them. A small state machine:
## IDLE (wait for a player in range) -> CHASE -> ATTACK (wind-up, swing, recover) -> CHASE ... -> DEAD

enum State { IDLE, CHASE, ATTACK, DEAD }

const LEAN_BACK: float = 0.436 ## ~25 degrees, in radians.
const LEAN_FORWARD: float = -0.262 ## ~-15 degrees.
const KNOCKBACK_DECAY: float = 30.0 ## Speed lost per second while being pushed.
const HIT_STOP: float = 0.04
const KILL_HIT_STOP: float = 0.08
const KILL_SHAKE: float = 0.15

@export var data: EnemyData
## Chase from any distance (set by spawners). Otherwise waits for detection_range.
@export var hunt_from_start: bool = false
## Scales max HP from data (set by spawners for later waves).
@export var health_multiplier: float = 1.0

var state: State = State.IDLE
var target: Node3D = null

var _state_time: float = 0.0
var _has_swung: bool = false
var _knockback: Vector3 = Vector3.ZERO
var _tween: Tween
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var stats: StatsComponent = $StatsComponent
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var melee: MeleeAttackComponent = $MeleeAttack
@onready var visual: Node3D = $Visual
@onready var body_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	if data:
		stats.max_health = data.max_health
		stats.attack_power = data.attack_power
		stats.defense = data.defense
		health.set_max_health(roundi(data.max_health * health_multiplier * GameState.enemy_health_multiplier()))
	health.damaged.connect(_on_damaged)
	hurtbox.hurt.connect(_on_hurt)
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_state_time += delta
	match state:
		State.IDLE:
			_process_idle()
		State.CHASE:
			_process_chase()
		State.ATTACK:
			_process_attack()
	# Knockback overrides whatever the state wanted to do this frame.
	if _knockback != Vector3.ZERO:
		velocity.x = _knockback.x
		velocity.z = _knockback.z
		_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()


func _change_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	if new_state == State.ATTACK:
		_has_swung = false
		velocity.x = 0.0
		velocity.z = 0.0
		_animate_lean(LEAN_BACK, data.attack_windup)


func _process_idle() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	target = _find_nearest_player()
	if target and (hunt_from_start or _flat_distance_to(target) <= data.detection_range):
		_change_state(State.CHASE)


func _process_chase() -> void:
	if not _is_target_valid():
		target = _find_nearest_player()
		if target == null:
			_change_state(State.IDLE)
			return
	if _flat_distance_to(target) <= data.attack_range:
		_change_state(State.ATTACK)
		return
	var dir: Vector3 = _flat_direction_to(target)
	velocity.x = dir.x * data.move_speed
	velocity.z = dir.z * data.move_speed
	visual.rotation.y = atan2(-dir.x, -dir.z)


func _process_attack() -> void:
	if not _has_swung and _state_time >= data.attack_windup:
		_has_swung = true
		var dir: Vector3 = _flat_direction_to(target) if _is_target_valid() else -visual.global_basis.z
		visual.rotation.y = atan2(-dir.x, -dir.z)
		melee.attack(dir)
		_animate_lean(LEAN_FORWARD, 0.05)
		_tween.tween_property(visual, "rotation:x", 0.0, data.attack_recovery * 0.5)
	elif _has_swung and _state_time >= data.attack_windup + data.attack_recovery:
		_change_state(State.CHASE)


func _find_nearest_player() -> Node3D:
	return Targeting.nearest_player(self)


func _is_target_valid() -> bool:
	return Targeting.is_alive(target)


func _flat_distance_to(node: Node3D) -> float:
	var offset: Vector3 = node.global_position - global_position
	offset.y = 0.0
	return offset.length()


func _flat_direction_to(node: Node3D) -> Vector3:
	var offset: Vector3 = node.global_position - global_position
	offset.y = 0.0
	return offset.normalized()


## Leaning is the telegraph: shape/motion, not color, so it reads for everyone.
func _animate_lean(angle: float, duration: float) -> void:
	_restart_tween()
	_tween.tween_property(visual, "rotation:x", angle, duration)


func _restart_tween() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()


func _on_hurt(_amount: int, hitbox: HitboxComponent) -> void:
	var away: Vector3 = global_position - hitbox.global_position
	away.y = 0.0
	var resistance: float = data.knockback_resistance if data else 0.0
	_knockback = away.normalized() * hitbox.knockback * (1.0 - resistance)
	GameFeel.hit_stop(get_tree(), HIT_STOP)


func _on_damaged(_amount: int) -> void:
	if state == State.DEAD:
		return
	visual.scale = Vector3(1.2, 0.8, 1.2)
	create_tween().tween_property(visual, "scale", Vector3.ONE, 0.12)


## Removed without dying (no kill credit), e.g. to clear the arena for a boss.
func despawn() -> void:
	if state == State.DEAD:
		return
	_change_state(State.DEAD)
	body_shape.set_deferred("disabled", true)
	hurtbox.set_deferred("monitoring", false)
	melee.hitbox.active = false
	_restart_tween()
	_tween.tween_property(visual, "scale", Vector3(0.05, 0.05, 0.05), 0.3)
	_tween.tween_callback(queue_free)


func _on_died() -> void:
	_change_state(State.DEAD)
	velocity = Vector3.ZERO
	body_shape.set_deferred("disabled", true)
	hurtbox.set_deferred("monitoring", false)
	melee.hitbox.active = false
	EventBus.enemy_killed.emit(self)
	GameFeel.hit_stop(get_tree(), KILL_HIT_STOP)
	GameFeel.shake(KILL_SHAKE)
	_restart_tween()
	_tween.tween_property(visual, "scale", Vector3(1.4, 0.05, 1.4), 0.25)
	_tween.tween_callback(queue_free)
