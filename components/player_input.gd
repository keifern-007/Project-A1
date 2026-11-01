class_name PlayerInput
extends Node
## The player's "input source". The player only asks this node what to do, never Input directly,
## so in Phase 5 a network peer can be swapped in here without touching movement code.
## Directions come out in world space, already adjusted for the camera angle.

const STICK_AIM_DEADZONE: float = 0.3

## Local device input. Later: which joypad/peer this source reads from.
@export var enabled: bool = true

## While disabled, an NPC brain can steer the body through here (e.g. walking home in camp).
var scripted_direction: Vector3 = Vector3.ZERO

var _mouse_aiming: bool = false
var _mouse_position: Vector2 = Vector2.ZERO


# Mouse motion is forwarded into the game viewport by RetroView, already in low-res coordinates.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_aiming = true
		_mouse_position = (event as InputEventMouseMotion).position


func get_move_direction() -> Vector3:
	if not enabled:
		return scripted_direction
	return _to_world(Input.get_vector("move_left", "move_right", "move_up", "move_down"))


## World-space aim direction from `origin`, or ZERO if not aiming (caller uses facing instead).
## Right stick wins; touching the mouse switches back to mouse aim.
func get_aim_direction(origin: Vector3) -> Vector3:
	if not enabled:
		return Vector3.ZERO
	var follow_camera: CameraFollow = get_viewport().get_camera_3d() as CameraFollow
	if follow_camera and follow_camera.is_third_person():
		return follow_camera.aim_direction(origin) # Over the shoulder: you aim where you look.
	var stick: Vector2 = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > STICK_AIM_DEADZONE:
		_mouse_aiming = false
		return _to_world(stick).normalized()
	if _mouse_aiming:
		return _mouse_direction(origin)
	return Vector3.ZERO


## Held, so keeping the button down keeps attacking.
func is_attack_pressed() -> bool:
	return enabled and Input.is_action_pressed("attack")


## Pressed this frame, for one-shot interactions (camp stations, NPCs).
func is_interact_pressed() -> bool:
	return enabled and Input.is_action_just_pressed("interact")


## Held, for channelled actions like gathering.
func is_interact_held() -> bool:
	return enabled and Input.is_action_pressed("interact")


func is_dodge_pressed() -> bool:
	return enabled and Input.is_action_just_pressed("dodge")


## Pressed this frame: use the loadout's consumable (potion etc.).
func is_consumable_pressed() -> bool:
	return enabled and Input.is_action_just_pressed("use_consumable")


## slot is 1–4, matching the skill_1..skill_4 actions.
func is_skill_pressed(slot: int) -> bool:
	return enabled and Input.is_action_just_pressed("skill_%d" % slot)


## Turns a 2D stick/WASD vector into a flat 3D direction, so "up" always means "up the screen".
func _to_world(input_vec: Vector2) -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or input_vec == Vector2.ZERO:
		return Vector3(input_vec.x, 0.0, input_vec.y)
	var right: Vector3 = camera.global_basis.x
	var forward: Vector3 = -camera.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	var dir: Vector3 = right.normalized() * input_vec.x - forward.normalized() * input_vec.y
	return dir.limit_length(1.0)


## Where the mouse points on the ground plane at origin's height.
func _mouse_direction(origin: Vector3) -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.ZERO
	var ground: Plane = Plane(Vector3.UP, origin.y)
	var hit: Variant = ground.intersects_ray(
		camera.project_ray_origin(_mouse_position), camera.project_ray_normal(_mouse_position))
	if hit == null:
		return Vector3.ZERO
	var dir: Vector3 = (hit as Vector3) - origin
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.1 else Vector3.ZERO
