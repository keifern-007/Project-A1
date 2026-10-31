class_name SwarmEnemy
extends Enemy
## Small, fast and fragile; comes in packs and surrounds you (Skitterling).
## IDLE -> CHASE (each one comes in from its own angle) -> CROUCH (the telegraph) -> HOP (a short
## leap; the bite is live during it) -> RECOVER -> CHASE ...
## Area skills (Whirlwind, Ground Slam, Fan of Knives) are the answer.

enum State { IDLE, CHASE, CROUCH, HOP, RECOVER }

@export var hop_speed: float = 6.0
@export var hop_time: float = 0.25
@export var hop_height: float = 0.35
@export var flank_radius: float = 1.8 ## How far to the side of you it aims while closing in.
@export var flank_until: float = 2.2 ## Closer than this it comes straight at you.

var state: State = State.IDLE

var _state_time: float = 0.0
var _hop_dir: Vector3 = Vector3.FORWARD
var _flank_offset: Vector3 = Vector3.ZERO

@onready var bite: HitboxComponent = $Visual/BiteHitbox


func _ready() -> void:
	super._ready()
	bite.active = false
	# Run RNG (not randf) so co-op peers agree on where each one goes.
	var angle: float = GameState.rng.randf() * TAU
	_flank_offset = Vector3(cos(angle), 0.0, sin(angle)) * flank_radius


func _behave(delta: float) -> void:
	_state_time += delta
	match state:
		State.IDLE:
			stand_still()
			target = find_nearest_player()
			if target and (hunt_from_start or flat_distance_to(target) <= data.detection_range):
				_change_state(State.CHASE)
		State.CHASE:
			_process_chase()
		State.CROUCH:
			stand_still()
			if is_target_valid():
				face(flat_direction_to(target))
			if _state_time >= data.attack_windup:
				_change_state(State.HOP)
		State.HOP:
			velocity.x = _hop_dir.x * hop_speed
			velocity.z = _hop_dir.z * hop_speed
			if _state_time >= hop_time:
				_change_state(State.RECOVER)
		State.RECOVER:
			stand_still()
			if _state_time >= data.attack_recovery:
				_change_state(State.CHASE)


func _process_chase() -> void:
	if not refresh_target():
		_change_state(State.IDLE)
		return
	var distance: float = flat_distance_to(target)
	if distance <= data.attack_range:
		_change_state(State.CROUCH)
		return
	var goal: Vector3 = target.global_position
	if distance > flank_until:
		goal += _flank_offset
	var to_goal: Vector3 = goal - global_position
	to_goal.y = 0.0
	walk(to_goal.normalized())


func _change_state(new_state: State) -> void:
	if state == State.HOP:
		bite.active = false
	state = new_state
	_state_time = 0.0
	match new_state:
		State.CROUCH:
			animate_lean(LEAN_BACK, data.attack_windup)
		State.HOP:
			_hop_dir = flat_direction_to(target) if is_target_valid() else -visual.global_basis.z
			face(_hop_dir)
			bite.damage = stats.get_attack_power()
			bite.active = true
			var hop: Tween = restart_tween().set_parallel()
			hop.tween_property(visual, "rotation:x", LEAN_FORWARD, hop_time * 0.5)
			hop.tween_property(visual, "position:y", hop_height, hop_time * 0.5)
			hop.chain().tween_property(visual, "position:y", 0.0, hop_time * 0.5)
		State.RECOVER:
			animate_lean(0.0, 0.15)
			visual.position.y = 0.0


func _stop_attacking() -> void:
	bite.active = false
