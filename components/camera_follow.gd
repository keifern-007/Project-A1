class_name CameraFollow
extends Camera3D
## Two views of the same target, chosen by Settings.camera_mode and switched with the camera_toggle action:
## - Isometric: keeps the target centered at whatever angle the camera was placed in the editor.
## - Over the shoulder: mouse or right stick looks around, walls push the camera in, the mouse is locked.
## Over the shoulder only applies to a Player; anything else (the camp's hero browsing) stays isometric.
## Also does screen shake (requested through GameFeel.shake, never directly).

@export var target: Node3D
@export var smoothing: float = 8.0 ## Higher = tighter follow. 0 = snap.
@export var look_height: float = 1.0 ## Centers on the target's body, not its feet.

@export_group("Over the shoulder")
@export var shoulder_height: float = 1.75 ## The point the camera orbits, above the feet.
@export var shoulder_offset: float = 0.75 ## Hero sits this far left of center, so the crosshair is clear.
@export var distance: float = 4.3
@export var wall_margin: float = 0.3
@export var squeeze_rise: float = 0.5 ## Meters up per meter a wall pushes the camera in.
@export var squeeze_tilt_reach: float = 1.4 ## Keeps the tilt from pointing straight down when very close.
@export var fov_degrees: float = 68.0
@export var mouse_sensitivity: float = 0.0035 ## Radians per mouse pixel.
@export var stick_sensitivity: float = 2.8 ## Radians per second at full tilt.
@export var pitch_up_limit: float = 0.45 ## Radians above level.
@export var pitch_down_limit: float = 1.05 ## Radians below level.
@export var start_pitch: float = -0.22
@export var follow_rate: float = 18.0

@export_group("Shake")
@export var max_shake_offset: float = 0.35 ## World units at full trauma.
@export var shake_decay: float = 2.5 ## Trauma lost per second.

const ISO_PULL_BACK: float = 50.0
const WORLD_LAYER: int = 1 ## What pushes the camera in. Enemies and heroes never do.
const AIM_LAYERS: int = 1 | 4 ## World and enemy bodies: where the crosshair lands.
const AIM_RANGE: float = 45.0
const AIM_MIN_DISTANCE: float = 2.5 ## Closer than this, shooting at the point would turn the hero sideways.

var _offset: Vector3
var _trauma: float = 0.0
var _last_shake_usec: int = 0
## Cosmetic randomness gets its own RNG so it never consumes the run seed (co-op sync).
var _shake_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _iso_transform: Transform3D
var _third_person: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0
var _orbit_point: Vector3 = Vector3.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Must free the mouse when the game pauses. Movement checks for it.
	_iso_transform = global_transform
	# An orthographic view looks the same from further back, and tall scenery near the camera doesn't get sliced.
	_iso_transform.origin += global_basis.z * ISO_PULL_BACK
	EventBus.screen_shake_requested.connect(_on_shake_requested)
	EventBus.settings_changed.connect(func() -> void: _apply_mode(true))
	if target and not target.is_node_ready(): # A map's camera can start before its hero.
		await target.ready
	_apply_mode(true)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Follow something else (e.g. the camp overview point, then the hero you pick).
## snap = jump there now instead of gliding.
func set_target(new_target: Node3D, snap: bool = false) -> void:
	target = new_target
	_apply_mode(snap)


func is_third_person() -> bool:
	return _third_person


## Over the shoulder: the flat direction from `origin` to where the crosshair lands, so shots go where
## you aim even though the hero stands off-center.
func aim_direction(origin: Vector3) -> Vector3:
	var straight: Vector3 = -global_basis.z
	straight.y = 0.0
	straight = straight.normalized()
	var from: Vector3 = global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - global_basis.z * AIM_RANGE, AIM_LAYERS)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var point: Vector3 = hit["position"] if not hit.is_empty() else from - global_basis.z * AIM_RANGE
	var to_point: Vector3 = point - origin
	to_point.y = 0.0
	# A point behind or right beside the hero (a wall at the camera's back) is no use: aim straight.
	if to_point.length() < AIM_MIN_DISTANCE or to_point.normalized().dot(straight) < 0.5:
		return straight
	return to_point.normalized()


func _apply_mode(snap: bool) -> void:
	var was_third_person: bool = _third_person
	_third_person = Settings.camera_mode == Settings.CameraMode.OVER_THE_SHOULDER and target is Player
	if _third_person:
		projection = Camera3D.PROJECTION_PERSPECTIVE
		fov = fov_degrees
		if not was_third_person or snap:
			_look_behind(target)
	else:
		projection = Camera3D.PROJECTION_ORTHOGONAL
		var glide_from: Vector3 = global_position
		global_basis = _iso_transform.basis
		global_position = _iso_transform.origin
		if target:
			_offset = _centering_offset()
			global_position = target.global_position + _offset if snap or was_third_person else glide_from
	_update_mouse()


# Starts behind the hero, looking the way they face.
func _look_behind(player: Player) -> void:
	_yaw = player.visual.global_rotation.y
	_pitch = start_pitch
	_orbit_point = player.global_position + Vector3.UP * shoulder_height
	_place_over_shoulder()


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
	if target == null or get_tree().paused:
		return
	if _third_person:
		_follow_over_shoulder(delta)
		return
	var goal: Vector3 = target.global_position + _offset
	if smoothing <= 0.0:
		global_position = goal
	else:
		global_position = global_position.lerp(goal, 1.0 - exp(-smoothing * delta))


func _follow_over_shoulder(delta: float) -> void:
	var player: Player = target as Player
	if player and player.input.enabled:
		var stick: Vector2 = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		_turn(-stick.x * stick_sensitivity * delta, -stick.y * stick_sensitivity * delta)
	var goal: Vector3 = target.global_position + Vector3.UP * shoulder_height
	_orbit_point = _orbit_point.lerp(goal, 1.0 - exp(-follow_rate * delta))
	_place_over_shoulder()


func _place_over_shoulder() -> void:
	var view: Basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0), EULER_ORDER_YXZ)
	var pivot: Vector3 = _orbit_point + view.x * shoulder_offset
	var wanted: Vector3 = pivot + view.z * distance
	var hit: Dictionary = {}
	if is_inside_tree():
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(_orbit_point, wanted, WORLD_LAYER)
		hit = get_world_3d().direct_space_state.intersect_ray(query)
	var reach: float = distance
	if not hit.is_empty():
		reach = maxf(_orbit_point.distance_to(hit["position"]) - wall_margin, 0.1)
	# Squeezed by a wall: rise and tilt down, looking over the hero instead of into the back of their head.
	var rise: float = (distance - reach) * squeeze_rise
	var tilt: float = atan2(rise, maxf(reach, squeeze_tilt_reach))
	global_basis = Basis.from_euler(Vector3(_pitch - tilt, _yaw, 0.0), EULER_ORDER_YXZ)
	global_position = _orbit_point + view.x * shoulder_offset * reach / distance + view.z * reach + Vector3.UP * rise


func _turn(yaw_change: float, pitch_change: float) -> void:
	_yaw += yaw_change
	_pitch = clampf(_pitch + pitch_change, -pitch_down_limit, pitch_up_limit)


func _input(event: InputEvent) -> void:
	if not _third_person or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion:
		_turn(-motion.relative.x * mouse_sensitivity, -motion.relative.y * mouse_sensitivity)


# Shake runs on the real clock, so hit stop (Engine.time_scale) doesn't freeze or distort it.
func _process(_delta: float) -> void:
	_update_mouse()
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


## The mouse is locked only while actually playing over the shoulder. Any menu, pause, the results
## screen or death disables the hero's input or pauses the tree, and that frees it.
func _update_mouse() -> void:
	var playing: bool = _third_person and not get_tree().paused
	if playing:
		var player: Player = target as Player
		playing = player != null and player.is_node_ready() and player.input.enabled and player.is_alive()
	var wanted: Input.MouseMode = Input.MOUSE_MODE_CAPTURED if playing else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != wanted:
		Input.mouse_mode = wanted
