class_name CameraFollow
extends Camera3D
## Keeps the target in the center of the screen and smoothly follows it, at whatever
## angle and distance the camera was placed in the editor.
## Also does screen shake (requested through GameFeel.shake, never directly).

@export var target: Node3D
@export var smoothing: float = 8.0 ## Higher = tighter follow. 0 = snap.
@export var look_height: float = 1.0 ## Centers on the target's body, not its feet.

@export_group("Shake")
@export var max_shake_offset: float = 0.35 ## World units at full trauma.
@export var shake_decay: float = 2.5 ## Trauma lost per second.

var _offset: Vector3
var _trauma: float = 0.0
var _last_shake_usec: int = 0
## Cosmetic randomness gets its own RNG so it never consumes the run seed (co-op sync).
var _shake_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	if target:
		_offset = _centering_offset()
		global_position = target.global_position + _offset # Start centered, no slide-in.
	EventBus.screen_shake_requested.connect(_on_shake_requested)


## Follow something else (e.g. the camp overview point, then the hero you pick).
## snap = jump there now instead of gliding.
func set_target(new_target: Node3D, snap: bool = false) -> void:
	target = new_target
	_offset = _centering_offset()
	if snap:
		global_position = target.global_position + _offset


## Where the camera must sit, relative to the target, so its center line passes through
## the target. Keeps the editor's angle and distance; only the aim point changes.
func _centering_offset() -> Vector3:
	var focus_height: float = target.global_position.y + look_height
	var forward: Vector3 = -global_basis.z
	var aim_point: Vector3 = global_position
	if absf(forward.y) > 0.001:
		aim_point = global_position + forward * ((focus_height - global_position.y) / forward.y)
	return global_position - aim_point + Vector3(0.0, look_height, 0.0)


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var goal: Vector3 = target.global_position + _offset
	if smoothing <= 0.0:
		global_position = goal
	else:
		global_position = global_position.lerp(goal, 1.0 - exp(-smoothing * delta))


# Shake runs on the real clock, so hit stop (Engine.time_scale) doesn't freeze or distort it.
func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var real_delta: float = minf((now - _last_shake_usec) / 1_000_000.0, 0.1)
	_last_shake_usec = now
	_trauma = maxf(_trauma - shake_decay * real_delta, 0.0)
	# Squared trauma: small hits barely move, big hits really kick.
	var strength: float = _trauma * _trauma * max_shake_offset
	h_offset = _shake_rng.randf_range(-1.0, 1.0) * strength
	v_offset = _shake_rng.randf_range(-1.0, 1.0) * strength


func _on_shake_requested(trauma: float) -> void:
	_trauma = minf(_trauma + trauma, 1.0)
