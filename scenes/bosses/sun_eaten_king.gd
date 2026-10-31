class_name SunEatenKing
extends Boss
## A Boss with a sarcophagus phase: at each seal_threshold (66%, 33% HP) he seals himself in,
## invulnerable, and canopic jars rise around the arena. Each jar pulses a telegraphed shockwave;
## while sealed he also opens quicksand under you now and then. Break every jar and the lid flies
## off: he's dazed for unseal_daze seconds (the big punish window), then the fight resumes.
## The jars are objects, not enemies, so it stays a duel (team rule: no adds in boss fights).

const JARS_KEY: String = "OBJ_BREAK_JARS"
const LID_REST: Vector3 = Vector3(0.0, 2.4, -1.2) ## Must match the Lid node in the scene.

@export var seal_thresholds: Array[float] = [0.66, 0.33]
@export var jar_scene: PackedScene
@export var jar_count: int = 3
@export var jar_ring_radius: float = 9.0
@export var arena_center: Vector3 = Vector3.ZERO ## Every map's arena is centered on the origin.
@export var sealed_sink_interval: float = 4.5
@export var unseal_daze: float = 3.0

var _seals_done: int = 0
var _sealed: bool = false
var _jars_left: int = 0
var _sink_left: float = 0.0
var _daze_left: float = 0.0

@onready var sarcophagus: Node3D = $Sarcophagus
@onready var lid: Node3D = $Sarcophagus/Lid
@onready var seal_label: Label3D = $SealLabel
@onready var sand_sink: AreaRainMove = $Moves/SandSink


func _ready() -> void:
	super._ready()
	sarcophagus.visible = false
	seal_label.visible = false
	seal_label.text = tr("STATUS_SEALED")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _sealed:
		_sink_left -= delta
		if _sink_left <= 0.0:
			_sink_left = sealed_sink_interval
			_sink_under_target()
		_hold_still(delta)
		return
	if _daze_left > 0.0:
		_daze_left -= delta
		if _daze_left <= 0.0 and stun_label:
			stun_label.visible = false
		_hold_still(delta)
		return
	super._physics_process(delta)


func _on_damaged(amount: int) -> void:
	super._on_damaged(amount)
	if _sealed or state == State.DEAD or health.current <= 0 or _seals_done >= seal_thresholds.size():
		return
	if health.current <= health.max_health * seal_thresholds[_seals_done]:
		_seal()


func _seal() -> void:
	_seals_done += 1
	_sealed = true
	for move: BossMove in _moves:
		move.cancel()
	_change_state(State.RECOVER)
	velocity = Vector3.ZERO
	hurtbox.invulnerable = true
	status.clear() # A Burn/Poison already on him must not tick through the seal.
	seal_label.visible = true
	animator.windup(&"seal", 0.6)
	sarcophagus.visible = true
	lid.position = LID_REST
	lid.rotation = Vector3.ZERO
	sarcophagus.scale = Vector3(1.0, 0.05, 1.0)
	create_tween().tween_property(sarcophagus, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	GameFeel.shake(0.5)
	_spawn_jars()
	_sink_left = sealed_sink_interval * 0.5


func _spawn_jars() -> void:
	_jars_left = jar_count
	var offset: float = _seals_done * 0.6 # Different spots on each seal.
	for i: int in jar_count:
		var angle: float = offset + TAU * i / jar_count
		var jar: CanopicJar = jar_scene.instantiate()
		jar.first_pulse_delay = 1.5 + i * 1.2
		jar.broken.connect(_on_jar_broken)
		get_parent().add_child(jar)
		jar.global_position = arena_center + Vector3(cos(angle), 0.0, sin(angle)) * jar_ring_radius
	EventBus.objective_progress.emit(JARS_KEY, 0, jar_count)


func _on_jar_broken() -> void:
	_jars_left -= 1
	EventBus.objective_progress.emit(JARS_KEY, jar_count - _jars_left, jar_count)
	if _jars_left <= 0 and _sealed:
		_unseal()


func _unseal() -> void:
	_sealed = false
	hurtbox.invulnerable = false
	seal_label.visible = false
	var lid_flip: Tween = create_tween().set_parallel()
	lid_flip.tween_property(lid, "position", lid.position + Vector3(0.0, 3.0, -2.5), 0.4)
	lid_flip.tween_property(lid, "rotation:x", -1.5, 0.4)
	lid_flip.chain().tween_property(sarcophagus, "scale", Vector3(1.0, 0.05, 1.0), 0.4)
	lid_flip.chain().tween_callback(func() -> void: sarcophagus.visible = false)
	GameFeel.shake(0.6)
	_daze_left = unseal_daze
	if stun_label:
		stun_label.visible = true
	animator.recover(unseal_daze)
	_change_state(State.CHASE)
	# Back to the normal boss objective line on the HUD.
	var objective: ObjectiveData = GameState.objective as ObjectiveData
	if objective:
		EventBus.objective_progress.emit(objective.name_key, 0, 1)


func _sink_under_target() -> void:
	if not Targeting.is_alive(target):
		target = Targeting.nearest_player(self)
	if target:
		sand_sink.start(self, target, sand_sink.windup)


func _hold_still(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()
