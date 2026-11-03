class_name MapNavigation
extends NavigationRegion3D
## Works out where enemies can walk on the map it's added to, from the map's solid objects (world
## physics layer), as the run loads. Any map gets it without setup. Things that appear later (a boss's
## icicle walls) aren't included. Enemies ask for routes through EnemyPath.

const AGENT_RADIUS: float = 0.5 ## Routes keep this far from walls. About a goblin's width.
const LARGE_AGENT_RADIUS: float = 1.5 ## A second set of routes for bosses, which are far wider.
const AGENT_HEIGHT: float = 1.5
const WORLD_LAYER: int = 1

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
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.agent_radius = AGENT_RADIUS
	mesh.agent_height = AGENT_HEIGHT
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = WORLD_LAYER
	var bounds: AABB = _bounds_box()
	if bounds.size != Vector3.ZERO: # Only where heroes can go: the floor may reach far under the scenery.
		mesh.filter_baking_aabb = bounds
	var source: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, get_parent())
	_add_csg_floors(source)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	navigation_mesh = mesh
	_build_large_routes(mesh, source)


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


# The collider scan above skips CSG shapes, and the maps' floors are CSG boxes. Their top face is
# added as plain triangles (reading a mesh back from the graphics card would stall the game).
func _add_csg_floors(source: NavigationMeshSourceGeometryData3D) -> void:
	for node: Node in get_parent().find_children("*", "CSGBox3D", true, false):
		var floor_box: CSGBox3D = node
		if not floor_box.use_collision:
			continue
		var half: Vector3 = floor_box.size * 0.5
		var a: Vector3 = Vector3(-half.x, half.y, -half.z)
		var b: Vector3 = Vector3(half.x, half.y, -half.z)
		var c: Vector3 = Vector3(half.x, half.y, half.z)
		var d: Vector3 = Vector3(-half.x, half.y, half.z)
		source.add_faces(PackedVector3Array([a, b, c, a, c, d]), floor_box.global_transform)
