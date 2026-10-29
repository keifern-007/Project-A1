extends SkillEffect
## Teleports the caster a short way along `direction`, stopping before walls; briefly invulnerable.

const WORLD_LAYER: int = 1
const RAY_HEIGHT: float = 0.4 ## Low enough that fences and crates block it.

@export var distance: float = 6.0
@export var invulnerable_time: float = 0.3
@export var wall_margin: float = 0.6
@export var puff_time: float = 0.3

@onready var puff_start: MeshInstance3D = $PuffStart
@onready var puff_end: MeshInstance3D = $PuffEnd


func _ready() -> void:
	var from: Vector3 = caster.global_position
	var dir: Vector3 = Vector3(direction.x, 0.0, direction.z).normalized()
	var target: Vector3 = from + dir * distance
	var up: Vector3 = Vector3.UP * RAY_HEIGHT
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from + up, target + up, WORLD_LAYER)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		target = (hit["position"] as Vector3) - up - dir * wall_margin
		target.y = from.y
	(caster as Player).blink(target, invulnerable_time)
	for puff: MeshInstance3D in [puff_start, puff_end]:
		puff.top_level = true
	puff_start.global_position = from + Vector3.UP
	puff_end.global_position = target + Vector3.UP
	var tween: Tween = create_tween().set_parallel()
	for puff: MeshInstance3D in [puff_start, puff_end]:
		tween.tween_property(puff, "scale", Vector3.ONE * 1.6, puff_time)
		tween.tween_property(puff, "transparency", 1.0, puff_time)
	tween.chain().tween_callback(queue_free)
