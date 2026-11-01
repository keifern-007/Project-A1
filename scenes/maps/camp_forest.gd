class_name CampForest
extends Node3D
## Fills everything outside the camp's fence, or a map's bounds, with scenery, so the world never
## seems to end from any camera: forest, snowy pines or desert, by `palette`.
## Trees are MultiMeshes (hundreds of trees, a handful of draw calls) placed by their own RNG:
## scenery only, so it never touches the run seed. No collision: the camp's Bounds keep heroes in.
## The camera looks toward -X -Z, so a tall thing hides whatever is behind it in that direction:
## _hides_camp() keeps tall trees off the near sides, and bushes fill those instead.

const CELL: float = 3.3 ## One tree or bush per cell, at most.
const JITTER: float = 1.25
const SEED: int = 20261101
const CAMERA_SHIFT: float = 1.0 ## A point this high covers ground this far back along X and along Z.
const SHADOW_BAND: float = 11.0 ## Only trees this close to the fence cast shadows (cheaper).

enum Palette { FOREST, SNOW, DESERT }

@export var palette: Palette = Palette.FOREST
@export var flowers: bool = true
@export var camp_half_size: float = 20.6 ## Half the fence's width.
@export var extent: float = 56.0 ## How far the forest reaches from the center.
## Spots kept clear, as Vector3(x, z, radius): the windmill and the like.
@export var clearings: Array[Vector3] = []
## Spots kept free of trees, as Rect2 on X/Z: the road out of camp.
@export var roads: Array[Rect2] = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _parts: Dictionary = {} # part name -> { mesh, transforms[], colors[], shadow }


func _ready() -> void:
	_rng.seed = SEED
	_scatter()
	if flowers:
		_add_flowers()
	_build_all()


func _scatter() -> void:
	var cells: int = ceili(extent * 2.0 / CELL)
	for i: int in cells:
		for j: int in cells:
			var x: float = -extent + (i + 0.5) * CELL + _rng.randf_range(-JITTER, JITTER)
			var z: float = -extent + (j + 0.5) * CELL + _rng.randf_range(-JITTER, JITTER)
			# Rolled for every cell, so a change in one spot doesn't reshuffle the whole forest.
			var kind: float = _rng.randf()
			var size: float = _rng.randf_range(0.9, 1.45)
			var shade: float = _rng.randf_range(-0.05, 0.07)
			if _inside_camp(x, z, 1.2) or _in_clearing(x, z) or _on_road(x, z):
				continue
			var height: float = (6.8 if kind < 0.35 else 5.0) * size
			if _hides_camp(x, z, height):
				if _rng.randf() < 0.75:
					_add_bush(x, z, size, shade)
			elif palette == Palette.DESERT:
				_add_rock(x, z, size, shade, kind)
			elif palette == Palette.SNOW or kind < 0.35:
				_add_pine(x, z, size, shade)
			else:
				_add_round_tree(x, z, size, shade)


## Desert: big dunes with sandstone outcrops, instead of trees.
func _add_rock(x: float, z: float, size: float, shade: float, kind: float) -> void:
	var sand: Color = Color(0.86 + shade, 0.7 + shade, 0.44 + shade)
	if kind < 0.6:
		_put("dune", _sphere_mesh(3.2, 3.2), x, 0.2, z, Vector3(size, size * 0.8, size), sand, false)
	else:
		var stone: Color = Color(0.72 + shade, 0.5 + shade, 0.34 + shade)
		_put("rock", _cone_mesh(1.7, 4.2), x, 1.9 * size, z, Vector3(size, size, size), stone, _near_fence(x, z))
		_put("rock_top", _sphere_mesh(1.2, 1.5), x + 0.2, 4.0 * size, z, Vector3(size, size, size), stone.lightened(0.08), false)


func _inside_camp(x: float, z: float, margin: float) -> bool:
	var half: float = camp_half_size + margin
	return absf(x) < half and absf(z) < half


func _in_clearing(x: float, z: float) -> bool:
	for clearing: Vector3 in clearings:
		if Vector2(x - clearing.x, z - clearing.y).length() < clearing.z:
			return true
	return false


func _on_road(x: float, z: float) -> bool:
	for road: Rect2 in roads:
		if road.has_point(Vector2(x, z)):
			return true
	return false


## Would something this tall, standing here, cover part of the walkable camp on screen?
func _hides_camp(x: float, z: float, height: float) -> bool:
	var reach: float = height * CAMERA_SHIFT
	# The object covers the diagonal from (x, z) to (x - reach, z - reach), plus its own width.
	for step: int in 9:
		var t: float = reach * step / 8.0
		if _inside_camp(x - t, z - t, 2.0):
			return true
	return false


func _add_round_tree(x: float, z: float, size: float, shade: float) -> void:
	var leaf: Color = Color(0.3 + shade, 0.55 + shade * 1.6, 0.22 + shade * 0.4)
	var shadow: bool = _near_fence(x, z)
	_put("trunk", _trunk_mesh(), x, 1.5 * size, z, Vector3(size, size, size), Color(0.45, 0.31, 0.2), shadow)
	_put("canopy", _sphere_mesh(1.9, 3.4), x, 3.9 * size, z, Vector3(size, size, size), leaf, shadow)
	_put("canopy_top", _sphere_mesh(1.25, 2.3), x + 0.4, 5.0 * size, z - 0.3, Vector3(size, size, size), leaf.lightened(0.1), false)


func _add_pine(x: float, z: float, size: float, shade: float) -> void:
	var needles: Color = Color(0.16 + shade, 0.42 + shade * 1.4, 0.24 + shade * 0.5)
	if palette == Palette.SNOW: # Dark below, snow-laden on top.
		needles = Color(0.34 + shade, 0.46 + shade, 0.46 + shade)
	var shadow: bool = _near_fence(x, z)
	_put("trunk", _trunk_mesh(), x, 1.5 * size, z, Vector3(size * 0.8, size, size * 0.8), Color(0.4, 0.27, 0.18), shadow)
	_put("pine_low", _cone_mesh(1.9, 2.8), x, 2.9 * size, z, Vector3(size, size, size), needles, shadow)
	var snow_up: float = 0.45 if palette == Palette.SNOW else 0.0
	_put("pine_mid", _cone_mesh(1.5, 2.4), x, 4.4 * size, z, Vector3(size, size, size), needles.lightened(0.06 + snow_up), false)
	_put("pine_top", _cone_mesh(1.0, 2.0), x, 5.8 * size, z, Vector3(size, size, size), needles.lightened(0.12 + snow_up * 1.5), false)


func _add_bush(x: float, z: float, size: float, shade: float) -> void:
	var color: Color = Color(0.34 + shade, 0.6 + shade * 1.5, 0.26 + shade * 0.4)
	match palette:
		Palette.SNOW:
			color = Color(0.88 + shade, 0.92 + shade, 0.96 + shade)
		Palette.DESERT:
			color = Color(0.84 + shade, 0.68 + shade, 0.42 + shade)
	var scale_vec: Vector3 = Vector3(size, size * 0.8, size)
	_put("bush", _sphere_mesh(1.0, 1.5), x, 0.55 * size, z, scale_vec, color, false)
	_put("bush", _sphere_mesh(1.0, 1.5), x + 0.8, 0.4 * size, z + 0.4, scale_vec * 0.7, color.lightened(0.08), false)


## Little dots of color on the camp's grass, off the plaza and roads.
func _add_flowers() -> void:
	var colors: Array[Color] = [Color(0.98, 0.95, 0.5), Color(0.96, 0.96, 0.98), Color(0.9, 0.45, 0.6), Color(0.65, 0.55, 0.95)]
	for patch: int in 46:
		var center: Vector2 = Vector2(_rng.randf_range(-19.0, 19.0), _rng.randf_range(-19.0, 19.0))
		var color: Color = colors[_rng.randi_range(0, colors.size() - 1)]
		for flower: int in 7:
			var spot: Vector2 = center + Vector2(_rng.randf_range(-1.1, 1.1), _rng.randf_range(-1.1, 1.1))
			if spot.length() > 8.5 and not _on_road(spot.x, spot.y):
				_put("flower", _sphere_mesh(0.09, 0.14), spot.x, 0.14, spot.y, Vector3.ONE, color, false)


func _near_fence(x: float, z: float) -> bool:
	return _inside_camp(x, z, SHADOW_BAND)


func _put(part: String, mesh: Mesh, x: float, y: float, z: float, size: Vector3, color: Color, shadow: bool) -> void:
	var key: String = part + ("_shadow" if shadow else "")
	if not _parts.has(key):
		_parts[key] = { "mesh": mesh, "transforms": [], "colors": [], "shadow": shadow }
	var spin: float = _rng.randf_range(0.0, TAU)
	var basis_now: Basis = Basis(Vector3.UP, spin).scaled(size)
	_parts[key]["transforms"].append(Transform3D(basis_now, Vector3(x, y, z)))
	_parts[key]["colors"].append(color)


func _build_all() -> void:
	for key: String in _parts:
		var part: Dictionary = _parts[key]
		var multimesh: MultiMesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = part["mesh"]
		multimesh.instance_count = part["transforms"].size()
		for i: int in multimesh.instance_count:
			multimesh.set_instance_transform(i, part["transforms"][i])
			multimesh.set_instance_color(i, part["colors"][i])
		var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		if not part["shadow"]:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)


func _tinted_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true # Instance colors are written in the usual sRGB values.
	return material


func _trunk_mesh() -> Mesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.25
	mesh.bottom_radius = 0.42
	mesh.height = 3.0
	mesh.radial_segments = 6
	mesh.rings = 1
	mesh.material = _tinted_material()
	return mesh


func _sphere_mesh(radius: float, height: float) -> Mesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = _tinted_material()
	return mesh


func _cone_mesh(radius: float, height: float) -> Mesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	mesh.material = _tinted_material()
	return mesh
