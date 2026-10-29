class_name OgreBoss
extends CharacterBody3D
## Dark Souls-style placeholder boss: huge, slow, readable. Every attack is
## telegraph (pose + ground marker) -> hit -> punish window. It never flinches.
## Below half HP it enrages: everything speeds up and its sweep can chain into the smash.

enum State { INTRO, CHASE, WINDUP, STRIKE, RECOVER, DEAD }

const INTRO_TIME: float = 1.8
const TURN_SPEED: float = 2.2 ## Radians/sec. Slow on purpose — circling behind it is a real tactic.
const ENRAGE_AT: float = 0.5
const ENRAGE_SPEED: float = 1.35
const COMBO_CHANCE: float = 0.6
const FACING_TO_ATTACK: float = 0.8 ## Only swings at things roughly in front of it.
const STOP_DISTANCE: float = 2.6
const LEAP_HEIGHT: float = 3.0
const LEAP_AIR_START: float = 0.6 ## Part of the leap windup spent crouching before take-off.
const HIT_STOP: float = 0.03
const DEATH_HIT_STOP: float = 0.25

@export var data: EnemyData

var state: State = State.INTRO
var target: Node3D = null

var _state_time: float = 0.0 ## Scaled by _speed, so enraged timers run faster.
var _attack: BossAttack
var _attacks: Array[BossAttack] = []
var _enraged: bool = false
var _speed: float = 1.0
var _leap_from: Vector3 = Vector3.ZERO
var _leap_to: Vector3 = Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var stats: StatsComponent = $StatsComponent
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var animator: OgreAnimator = $OgreAnimator
@onready var body_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	if data:
		stats.max_health = data.max_health
		stats.defense = data.defense
		health.set_max_health(roundi(data.max_health * GameState.enemy_health_multiplier()))
	for child: Node in $Attacks.get_children():
		if child is BossAttack:
			_attacks.append(child)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	hurtbox.hurt.connect(_on_hurt)
	animator.roar(INTRO_TIME)
	get_tree().create_timer(INTRO_TIME * 0.35).timeout.connect(func() -> void: GameFeel.shake(0.8))
	EventBus.boss_spawned.emit(self)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_state_time += delta * _speed
	match state:
		State.INTRO:
			if _state_time >= INTRO_TIME:
				_change_state(State.CHASE)
		State.CHASE:
			_process_chase(delta)
		State.WINDUP:
			if _process_windup(delta):
				return # Airborne mid-leap: position is set directly, skip physics.
		State.STRIKE:
			if _state_time >= _attack.active_time:
				_attack.end_strike()
				_after_strike()
		State.RECOVER:
			if _state_time >= _attack.recovery:
				_change_state(State.CHASE)
	if state != State.CHASE:
		velocity.x = 0.0
		velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()


func _change_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0


func _process_chase(delta: float) -> void:
	if not Targeting.is_alive(target):
		target = Targeting.nearest_player(self)
		if target == null:
			velocity.x = 0.0
			velocity.z = 0.0
			return
	_turn_toward(target.global_position, delta)
	var distance: float = Targeting.flat_distance(global_position, target.global_position)
	var attack: BossAttack = _pick_attack(distance)
	if attack:
		_start_attack(attack)
		return
	# Walks the way it faces, so its slow turning really matters.
	var speed: float = data.move_speed * _speed if distance > STOP_DISTANCE else 0.0
	var forward: Vector3 = -global_basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed


## Weighted random pick among attacks that fit the distance. Seeded RNG keeps co-op in sync.
func _pick_attack(distance: float) -> BossAttack:
	var facing: float = _facing_dot(target.global_position)
	var options: Array[BossAttack] = []
	var total_weight: float = 0.0
	for attack: BossAttack in _attacks:
		if attack.is_usable(distance) and (attack.pose == BossAttack.Pose.LEAP or facing > FACING_TO_ATTACK):
			options.append(attack)
			total_weight += attack.weight
	if options.is_empty():
		return null
	var roll: float = GameState.rng.randf() * total_weight
	for attack: BossAttack in options:
		roll -= attack.weight
		if roll <= 0.0:
			return attack
	return options.back()


func _start_attack(attack: BossAttack) -> void:
	_attack = attack
	_change_state(State.WINDUP)
	var real_windup: float = attack.windup / _speed
	attack.show_telegraph(real_windup)
	animator.windup(attack.pose, real_windup)
	if attack.pose == BossAttack.Pose.LEAP:
		_leap_from = global_position
		_leap_to = _ground_point(target.global_position)
		attack.place_marker(_leap_to)


## Returns true while airborne (caller skips move_and_slide).
func _process_windup(delta: float) -> bool:
	var t: float = _state_time / _attack.windup
	if t < _attack.track_fraction and Targeting.is_alive(target):
		_turn_toward(target.global_position, delta)
		if _attack.pose == BossAttack.Pose.LEAP:
			_leap_to = _ground_point(target.global_position)
			_attack.place_marker(_leap_to)
	if t >= 1.0:
		_strike()
		return false
	if _attack.pose == BossAttack.Pose.LEAP and t >= LEAP_AIR_START:
		var air: float = (t - LEAP_AIR_START) / (1.0 - LEAP_AIR_START)
		var pos: Vector3 = _leap_from.lerp(_leap_to, air)
		pos.y = _leap_from.y + sin(air * PI) * LEAP_HEIGHT
		global_position = pos
		return true
	return false


func _strike() -> void:
	if _attack.pose == BossAttack.Pose.LEAP:
		global_position = _leap_to
	_change_state(State.STRIKE)
	_attack.strike()
	animator.strike(_attack.pose)


func _after_strike() -> void:
	# Enraged: the sweep can flow straight into the smash with no punish window in between.
	if _enraged and _attack.pose == BossAttack.Pose.SWEEP and GameState.rng.randf() < COMBO_CHANCE:
		var smash: BossAttack = _find_attack(BossAttack.Pose.OVERHEAD)
		if smash:
			_start_attack(smash)
			return
	_change_state(State.RECOVER)
	animator.recover(_attack.recovery / _speed)


func _find_attack(pose: BossAttack.Pose) -> BossAttack:
	for attack: BossAttack in _attacks:
		if attack.pose == pose:
			return attack
	return null


func _turn_toward(point: Vector3, delta: float) -> void:
	var dir: Vector3 = point - global_position
	if Vector2(dir.x, dir.z).length() < 0.01:
		return
	rotation.y = rotate_toward(rotation.y, atan2(-dir.x, -dir.z), TURN_SPEED * _speed * delta)


func _facing_dot(point: Vector3) -> float:
	var dir: Vector3 = point - global_position
	dir.y = 0.0
	return (-global_basis.z).dot(dir.normalized())


func _ground_point(point: Vector3) -> Vector3:
	return Vector3(point.x, global_position.y, point.z)


func _on_hurt(_amount: int, _hitbox: HitboxComponent) -> void:
	GameFeel.hit_stop(get_tree(), HIT_STOP)


func _on_damaged(_amount: int) -> void:
	if not _enraged and health.current <= health.max_health * ENRAGE_AT:
		_enraged = true
		_speed = ENRAGE_SPEED
		GameFeel.shake(0.6)


func _on_died() -> void:
	if state == State.WINDUP and _attack and _attack.pose == BossAttack.Pose.LEAP:
		global_position.y = _leap_from.y # Don't leave a corpse floating mid-leap.
	_change_state(State.DEAD)
	for attack: BossAttack in _attacks:
		attack.cancel()
	velocity = Vector3.ZERO
	body_shape.set_deferred("disabled", true)
	hurtbox.set_deferred("monitoring", false)
	GameFeel.hit_stop(get_tree(), DEATH_HIT_STOP)
	GameFeel.shake(1.0)
	animator.die()
	EventBus.enemy_killed.emit(self)
	EventBus.boss_defeated.emit(self)
