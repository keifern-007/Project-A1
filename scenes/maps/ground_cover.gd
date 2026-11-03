class_name GroundCover
extends Node3D
## Grass tufts, wildflowers and pebbles over a map's open ground, so big fields don't look empty.
## Thousands of them in a few MultiMeshes (a handful of draw calls), no collision: looks only.
## It finds the floor by casting a ray down at each spot after the first physics frame, and only
## grows on floors (group "no_fade"), never on props, paths it's told to keep clear, or in clearings.
## Its own RNG (scenery, never the run seed).

const SEED: int = 20261104
const GRASS_COLORS: Array[Color] = [Color(0.36, 0.55, 0.24), Color(0.44, 0.62, 0.28), Color(0.3, 0.48, 0.22)]
const FLOWER_COLORS: Array[Color] = [Color(0.98, 0.92, 0.45), Color(0.96, 0.96, 0.98), Color(0.88, 0.45, 0.62), Color(0.62, 0.55, 0.95)]

@export var half_size: float = 100.0 ## Covers -half_size..half_size on X and Z.
@export var spacing: float = 2.2 ## One spot per this many metres (then jittered).
@export_range(0.0, 1.0) var flower_chance: float = 0.12
@export_range(0.0, 1.0) var pebble_chance: float = 0.06
## Spots kept bare, as Vector3(x, z, radius): base camp and the like.
@export var clearings: Array[Vector3] = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _grass: Array[Transform3D] = []
var _grass_colors: Array[Color] = []
var _flowers: Array[Transform3D] = []
var _flower_colors: Array[Color] = []
var _pebbles: Array[Transform3D] = []


func _ready() -> void:
	_rng.seed = SEED
	await get_tree().physics_frame # The floors' collision must be in place before probing it.
	if not is_inside_tree():
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var steps: int = ceili(half_size * 2.0 / spacing)
	for i: int in steps:
		for j: int in steps:
			var x: float = -half_size + (i + 0.5) * spacing + _rng.randf_range(-0.9, 0.9)
			var z: float = -half_size + (j + 0.5) * spacing + _rng.randf_range(-0.9, 0.9)
			var kind: float = _rng.randf()
			if _in_clearing(x, z):
				continue
			var floor_y: float = _floor_at(space, x, z)
			if is_nan(floor_y):
				continue
			if kind < pebble_chance:
				_pebbles.append(_spin(Vector3(x, floor_y + 0.05, z), _rng.randf_range(0.6, 1.4)))
			elif kind < pebble_chance + flower_chance:
				_add_flower_patch(x, floor_y, z)
			else:
				_grass.append(_spin(Vector3(x, floor_y + 0.13, z), _rng.randf_range(0.7, 1.3)))
				_grass_colors.append(GRASS_COLORS[_rng.randi_range(0, GRASS_COLORS.size() - 1)])
	_build(_grass, _grass_colors, _grass_mesh())
	_build(_flowers, _flower_colors, _flower_mesh())
	_build(_pebbles, [], _pebble_mesh())


## The floor's height here, or NAN if there's a prop in the way (or nothing at all).
func _floor_at(space: PhysicsDirectSpaceState3D, x: float, z: float) -> float:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, 30.0, z), Vector3(x, -10.0, z), 1)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty() or not (hit["collider"] as Node).is_in_group("no_fade"):
		return NAN
	return (hit["position"] as Vector3).y


func _add_flower_patch(x: float, y: float, z: float) -> void:
	var color: Color = FLOWER_COLORS[_rng.randi_range(0, FLOWER_COLORS.size() - 1)]
	for k: int in 5:
		var spot: Vector3 = Vector3(x + _rng.randf_range(-0.7, 0.7), y + 0.16, z + _rng.randf_range(-0.7, 0.7))
		_flowers.append(_spin(spot, _rng.randf_range(0.8, 1.2)))
		_flower_colors.append(color)


func _in_clearing(x: float, z: float) -> bool:
	for clearing: Vector3 in clearings:
		if Vector2(x - clearing.x, z - clearing.y).length() < clearing.z:
			return true
	return false


func _spin(at: Vector3, size: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * size), at)


func _build(transforms: Array[Transform3D], colors: Array, mesh: Mesh) -> void:
	if transforms.is_empty():
		return
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = not colors.is_empty()
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
		if multimesh.use_colors:
			multimesh.set_instance_color(index, colors[index])
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = 90.0 # Far fields fade into the haze anyway.
	add_child(instance)


func _material(albedo: Color, use_vertex_color: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = albedo
	material.vertex_color_use_as_albedo = use_vertex_color
	material.vertex_color_is_srgb = true # Instance colors are written in the usual sRGB values.
	return material


## A tuft: a small three-sided cone, like a clump of blades.
func _grass_mesh() -> Mesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.14
	mesh.height = 0.26
	mesh.radial_segments = 3
	mesh.rings = 1
	mesh.material = _material(Color.WHITE, true)
	return mesh


func _flower_mesh() -> Mesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.12
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = _material(Color.WHITE, true)
	return mesh


func _pebble_mesh() -> Mesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.14
	mesh.radial_segments = 5
	mesh.rings = 2
	mesh.material = _material(Color(0.55, 0.53, 0.5), false)
	return mesh
