class_name Boss
extends CharacterBody3D
## Shared boss brain (new bosses; the Ogre still uses its own OgreBoss script).
## Huge, slow-turning and readable: it walks the way it faces, picks a BossMove from its "Moves" child
## (weighted, by distance and facing, with the run RNG so co-op stays in sync) and runs it:
## windup (telegraph) -> active -> recovery (punish window). It never flinches.
## Below phase_two_at HP it enters phase two: every timer speeds up, phase_two_only moves unlock
## and phase_two_scene (e.g. a thicker blizzard) is added to the arena.
## Scene needs: StatsComponent, HealthComponent, HurtboxComponent, StatusEffectComponent,
## CollisionShape3D, Visual, Animator (a BossAnimator), Moves (BossMove children); StunLabel optional.
## Hits from elements it's weak to fill a stagger gauge. When full, it's stunned and takes extra damage,
## but only after finishing any attack in progress: players can't interrupt a boss's attack (team rule).

## Hunted bosses (roam_points set before it's added): it wanders the map until a hero comes near or
## hits it, and limps off to another zone at each flee_at share of its HP. Only then does it announce
## itself (boss bar, camera lock). See BossRoaming.

signal phase_changed(phase: int)
signal stagger_changed(fraction: float, staggered: bool) ## The boss bar shows this in words.
signal fled ## A hunted boss is fleeing to another zone.

enum State { INTRO, CHASE, WINDUP, ACTIVE, RECOVER, DEAD, ROAM, FLEE }

const HIT_STOP: float = 0.03
const DEATH_HIT_STOP: float = 0.25

@export var data: EnemyData
@export var intro_time: float = 1.8
@export var turn_speed: float = 2.0 ## Radians/sec. Slow on purpose: circling behind it is a tactic.
@export var stop_distance: float = 2.8
@export_range(-1.0, 1.0) var facing_to_attack: float = 0.75 ## Dot product: how "in front" a target must be.
@export_range(0.0, 1.0) var phase_two_at: float = 0.5
@export var phase_two_speed: float = 1.25
@export var phase_two_scene: PackedScene ## Added to the arena when phase two starts.

@export_group("Hunt") ## Only used when roam_points are set.
@export var notice_range: float = 14.0 ## A hero this close is noticed.
@export var lose_range: float = 45.0 ## A hero who gets this far away is lost: back to wandering.
@export var flee_at: Array[float] = [0.66, 0.33] ## HP shares at which it limps away to another zone.
@export var flee_speed: float = 1.8 ## Times its normal speed while fleeing (set it so it outruns every hero).

var roam_points: Array[Vector3] = [] ## Set by the hunt before the boss is added. Empty = an arena boss.

var state: State = State.INTRO
var target: Node3D = null
var phase: int = 1
var speed_scale: float = 1.0 ## Phase two makes every timer run faster.

var _state_time: float = 0.0
var _move: BossMove
var _moves: Array[BossMove] = []
var _extra_recovery: float = 0.0
var _stagger_built: float = 0.0
var _stagger_pending: bool = false
var _stagger_left: float = 0.0
var _roaming: BossRoaming
var _route: EnemyPath
var _announced: bool = false
var _flees_done: int = 0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var stats: StatsComponent = $StatsComponent
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var status: StatusEffectComponent = $StatusEffectComponent
@onready var animator: BossAnimator = $Animator
@onready var visual: Node3D = $Visual
@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var stun_label: Label3D = get_node_or_null("StunLabel")


func _ready() -> void:
	if data:
		data = data.variant_for(GameState.biome())
		data.apply_look(visual)
	status.data = data
	if data:
		stats.max_health = data.max_health
		stats.attack_power = data.attack_power
		stats.defense = data.defense
		health.set_max_health(roundi(data.max_health * GameState.enemy_health_multiplier()))
	for child: Node in $Moves.get_children():
		if child is BossMove:
			_moves.append(child)
	if stun_label:
		stun_label.text = tr("STATUS_STUNNED")
		stun_label.visible = false
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	hurtbox.hurt.connect(_on_hurt)
	_route = EnemyPath.new(self, true)
	if roam_points.is_empty():
		_announce()
	else:
		_roaming = BossRoaming.new(self)
		_change_state(State.ROAM)


## The roar, the boss bar and the camera lock: the fight begins.
func _announce() -> void:
	_announced = true
	animator.roar(intro_time)
	get_tree().create_timer(intro_time * 0.35).timeout.connect(func() -> void: GameFeel.shake(0.8))
	EventBus.boss_spawned.emit(self)


## A hunted boss notices a hero: the first time with its roar, later straight back into the fight.
func engage(hero: Node3D) -> void:
	target = hero
	if _announced:
		_change_state(State.CHASE)
		return
	_announce()
	_change_state(State.INTRO)


func is_fleeing() -> bool:
	return state == State.FLEE


func stand() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


## Out of a fight: follows its route directly (sliding round corners) while turning to face it.
## In a fight it still walks the way it faces, so circling behind it stays a tactic.
func walk_along(direction: Vector3, speed: float, turn_delta: float) -> void:
	turn_toward(global_position + direction, turn_delta)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed


## Done fleeing: rest, and wander again.
func end_flee() -> void:
	if stun_label:
		stun_label.visible = false
	_change_state(State.ROAM)


func _start_flee() -> void:
	if state == State.WINDUP or state == State.ACTIVE:
		_move.cancel()
	cancel_stagger()
	_change_state(State.FLEE)
	animator.recover(0.6)
	if stun_label:
		stun_label.text = tr("STATUS_FLEEING")
		stun_label.visible = true
	_roaming.start_flee(target)
	fled.emit()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _stagger_pending and (state == State.CHASE or state == State.RECOVER):
		_start_stagger()
	if _stagger_left > 0.0:
		_process_stagger(delta)
		return
	_state_time += delta * speed_scale
	var move_drives_velocity: bool = false
	match state:
		State.INTRO:
			if _state_time >= intro_time:
				_change_state(State.CHASE)
		State.CHASE:
			_process_chase(delta)
		State.WINDUP:
			_process_windup(delta)
		State.ACTIVE:
			move_drives_velocity = _move.moves_boss
			if _move.active_process(self, _state_time, delta) or _state_time >= _move.active_time:
				_end_active()
		State.RECOVER:
			if _state_time >= _move.recovery + _extra_recovery:
				if stun_label:
					stun_label.visible = false
				_change_state(State.CHASE)
		State.ROAM, State.FLEE:
			_roaming.process(delta)
	var walking: bool = state == State.CHASE or state == State.ROAM or state == State.FLEE
	if not walking and not (state == State.ACTIVE and move_drives_velocity):
		velocity.x = 0.0
		velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()
	if state == State.ACTIVE:
		_move.after_move(self)


## The boss slammed into something mid-move (a charge into a wall): extra-long punish window.
func crash(stun_time: float) -> void:
	if state != State.ACTIVE:
		return
	_extra_recovery = stun_time
	if stun_label:
		stun_label.visible = true
	GameFeel.shake(0.6)
	_end_active()


## Drops a stagger in progress or waiting to start (the King's seal, death). The gauge stays.
func cancel_stagger() -> void:
	_stagger_pending = false
	if _stagger_left > 0.0:
		_stagger_left = 0.0
		hurtbox.damage_taken_multiplier /= data.stagger_damage_multiplier
		if stun_label:
			stun_label.text = tr("STATUS_STUNNED")
			stun_label.visible = false
		stagger_changed.emit(0.0, false)


func _on_hurt(amount: int, hitbox: HitboxComponent) -> void:
	GameFeel.hit_stop(get_tree(), HIT_STOP)
	if state == State.ROAM: # Hit before it noticed anyone.
		var hero: Node3D = Targeting.nearest_player(self)
		if hero:
			engage(hero)
	if data == null or data.stagger_threshold <= 0.0 or data.element_multiplier(hitbox.element) <= 1.0:
		return
	if _stagger_pending or _stagger_left > 0.0:
		return
	_stagger_built += amount
	var fraction: float = _stagger_built / (health.max_health * data.stagger_threshold)
	if fraction >= 1.0:
		_stagger_built = 0.0
		_stagger_pending = true
		fraction = 1.0
	stagger_changed.emit(fraction, false)


func _start_stagger() -> void:
	_stagger_pending = false
	_stagger_left = data.stagger_time
	hurtbox.damage_taken_multiplier *= data.stagger_damage_multiplier
	if stun_label:
		stun_label.text = tr("STATUS_STAGGERED")
		stun_label.visible = true
	GameFeel.shake(0.6)
	animator.recover(data.stagger_time)
	stagger_changed.emit(0.0, true)


func _process_stagger(delta: float) -> void:
	_stagger_left -= delta
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()
	if _stagger_left <= 0.0:
		_stagger_left = 0.001 # cancel_stagger undoes the bonus damage only while one is running.
		cancel_stagger()
		_change_state(State.CHASE)


func forward() -> Vector3:
	var dir: Vector3 = -global_basis.z
	dir.y = 0.0
	return dir.normalized()


func ground_point(point: Vector3) -> Vector3:
	return Vector3(point.x, global_position.y, point.z)


func turn_toward(point: Vector3, delta: float) -> void:
	var dir: Vector3 = point - global_position
	if Vector2(dir.x, dir.z).length() < 0.01:
		return
	rotation.y = rotate_toward(rotation.y, atan2(-dir.x, -dir.z), turn_speed * speed_scale * delta)


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
	var distance: float = Targeting.flat_distance(global_position, target.global_position)
	if _roaming and distance > lose_range:
		_roaming.lose_track()
		_change_state(State.ROAM)
		return
	# Up close it faces the hero; farther off it follows a route around obstacles (same thing in an open arena).
	var heading: Vector3 = target.global_position
	if distance > stop_distance * 2.0:
		heading = global_position + _route.direction_to(target.global_position, delta)
	turn_toward(heading, delta)
	var move: BossMove = _pick_move(distance)
	if move:
		_start_move(move)
		return
	# Walks the way it faces, so its slow turning really matters.
	var speed: float = data.move_speed * speed_scale * status.speed_multiplier() if distance > stop_distance else 0.0
	velocity.x = forward().x * speed
	velocity.z = forward().z * speed


func _pick_move(distance: float) -> BossMove:
	var dir: Vector3 = target.global_position - global_position
	dir.y = 0.0
	var facing: float = forward().dot(dir.normalized())
	var options: Array[BossMove] = []
	var total: float = 0.0
	for move: BossMove in _moves:
		if move.is_usable(self, distance, facing):
			options.append(move)
			total += move.weight
	if options.is_empty():
		return null
	var roll: float = GameState.rng.randf() * total
	for move: BossMove in options:
		roll -= move.weight
		if roll <= 0.0:
			return move
	return options.back()


func _start_move(move: BossMove) -> void:
	_move = move
	_extra_recovery = 0.0
	_change_state(State.WINDUP)
	var real_windup: float = move.windup / speed_scale
	move.start(self, target, real_windup)
	animator.windup(move.anim, real_windup)


func _process_windup(delta: float) -> void:
	var t: float = _state_time / _move.windup
	if t < _move.track_fraction and Targeting.is_alive(target):
		turn_toward(target.global_position, delta)
	_move.windup_process(self, minf(t, 1.0), delta)
	if t >= 1.0:
		_change_state(State.ACTIVE)
		_move.strike(self)
		animator.strike(_move.anim)


func _end_active() -> void:
	_move.finish(self)
	_change_state(State.RECOVER)
	animator.recover((_move.recovery + _extra_recovery) / speed_scale)


func _on_damaged(_amount: int) -> void:
	if _roaming and _flees_done < flee_at.size() and health.current > 0 \
			and health.current <= health.max_health * flee_at[_flees_done]:
		_flees_done += 1
		_start_flee()
	if phase == 1 and health.current <= health.max_health * phase_two_at:
		phase = 2
		speed_scale = phase_two_speed
		GameFeel.shake(0.6)
		if phase_two_scene:
			get_parent().add_child(phase_two_scene.instantiate())
		phase_changed.emit(phase)


func _on_died() -> void:
	cancel_stagger()
	_change_state(State.DEAD)
	for move: BossMove in _moves:
		move.cancel()
	if stun_label:
		stun_label.visible = false
	velocity = Vector3.ZERO
	body_shape.set_deferred("disabled", true)
	hurtbox.set_deferred("monitoring", false)
	GameFeel.hit_stop(get_tree(), DEATH_HIT_STOP)
	GameFeel.shake(1.0)
	animator.die()
	EventBus.enemy_killed.emit(self)
	EventBus.boss_defeated.emit(self)
