class_name MapNavigation
extends NavigationRegion3D
## Works out where enemies can walk on the map it's added to, from the map's solid objects (world
## physics layer), as the run loads. Any map gets it without setup. Things that appear later (a boss's
## icicle walls) aren't included. Enemies ask for routes through EnemyPath.

const AGENT_RADIUS: float = 0.5 ## Routes keep this far from walls. About a goblin's width.
const LARGE_AGENT_RADIUS: float = 1.5 ## A second set of routes for bosses, which are far wider.
const AGENT_HEIGHT: float = 1.5
const WORLD_LAYER: int = 1
const BODY_GROUP: StringName = &"nav_bodies"

## Routes for big creatures (bosses), on their own navigation map. Built in the background after the
## normal one, so it may not exist for the first moments: EnemyPath falls back to the normal routes.
static var large_map: RID = RID()

var _large_map: RID = RID()


func _exit_tree() -> void:
	if _large_map.is_valid():
		if large_map == _large_map:
			large_map = RID()
		NavigationServer3D.free_rid(_large_map)
		_large_map = RID()


func _ready() -> void:
	# CSG shapes (the floors, plateaus and cliffs maps are built from) build their collision a frame
	# after they enter the tree; their full surfaces are read from that collision below.
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.agent_radius = AGENT_RADIUS
	mesh.agent_height = AGENT_HEIGHT
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = WORLD_LAYER
	# Godot's own scan only reads the regular solid bodies, gathered in a group. CSG shapes are left to
	# _add_csg_shapes(): Godot's scan would read their meshes back from the graphics card (slow).
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	mesh.geometry_source_group_name = BODY_GROUP
	for body: Node in get_parent().find_children("*", "StaticBody3D", true, false):
		body.add_to_group(BODY_GROUP)
	var bounds: AABB = _bounds_box()
	if bounds.size != Vector3.ZERO: # Only where heroes can go: the floor may reach far under the scenery.
		mesh.filter_baking_aabb = bounds
	var source: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, get_parent())
	_add_csg_shapes(source)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	navigation_mesh = mesh
	# The wide routes are built in the background only once the normal ones are in use: started
	# together, the background job held up the normal routes for seconds on big maps.
	await _normal_routes_ready()
	if is_inside_tree():
		_build_large_routes(mesh, source)


## Waits until the navigation map answers with real routes (at most about 10 s, just in case).
func _normal_routes_ready() -> void:
	var map: RID = get_navigation_map()
	var probe: Vector3 = _any_floor()
	for frame: int in 600:
		if not is_inside_tree():
			return
		if NavigationServer3D.map_get_iteration_id(map) > 0 and NavigationServer3D.map_get_closest_point(map, probe) != Vector3.ZERO:
			return
		await get_tree().physics_frame


## A point that should be on a floor: the middle of the map's Bounds (good enough to see the routes exist).
func _any_floor() -> Vector3:
	var bounds: AABB = _bounds_box()
	return bounds.get_center() * Vector3(1, 0, 1) if bounds.size != Vector3.ZERO else Vector3.ZERO


func _build_large_routes(mesh: NavigationMesh, source: NavigationMeshSourceGeometryData3D) -> void:
	_large_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(_large_map, mesh.cell_size)
	NavigationServer3D.map_set_cell_height(_large_map, mesh.cell_height)
	NavigationServer3D.map_set_active(_large_map, true)
	var region: NavigationRegion3D = NavigationRegion3D.new()
	region.name = "LargeRoutes"
	add_child(region)
	region.set_navigation_map(_large_map)
	var large: NavigationMesh = mesh.duplicate()
	large.agent_radius = LARGE_AGENT_RADIUS
	NavigationServer3D.bake_from_source_geometry_data_async(large, source, func() -> void:
		if is_instance_valid(region):
			region.navigation_mesh = large
			large_map = _large_map)


## The space inside the map's "Bounds" walls (plus a little), or an empty box if it has none.
func _bounds_box() -> AABB:
	var walls: Node3D = get_parent().get_node_or_null("Bounds") as Node3D
	if walls == null:
		return AABB()
	var low: Vector3 = Vector3.INF
	var high: Vector3 = -Vector3.INF
	for shape: Node in walls.get_children():
		if shape is CollisionShape3D:
			low = low.min((shape as Node3D).global_position)
			high = high.max((shape as Node3D).global_position)
	if low == Vector3.INF:
		return AABB()
	return AABB(Vector3(low.x - 2.0, -50.0, low.z - 2.0), Vector3(high.x - low.x + 4.0, 100.0, high.z - low.z + 4.0))


# The collider scan above skips CSG shapes, and maps are mostly built from them. Their real surfaces
# (floors, walls, plateau sides, holes cut for water) come from their own collision, so a raised
# plateau is a wall at ground level too. (Reading their render mesh instead would stall the game.)
func _add_csg_shapes(source: NavigationMeshSourceGeometryData3D) -> void:
	for node: Node in get_parent().find_children("*", "CSGShape3D", true, false):
		var shape: CSGShape3D = node
		if not shape.is_root_shape() or not shape.use_collision or (shape.collision_layer & WORLD_LAYER) == 0:
			continue
		var collision: ConcavePolygonShape3D = shape.bake_collision_shape() as ConcavePolygonShape3D
		if collision and not collision.get_faces().is_empty():
			source.add_faces(collision.get_faces(), shape.global_transform)
