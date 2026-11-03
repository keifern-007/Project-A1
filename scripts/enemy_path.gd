class_name EnemyPath
extends RefCounted
## One enemy's route to wherever it's heading. Asks for a new route a few times a second, not every
## frame, so a full wave stays cheap. With no navigation on the map it just heads straight there.

const REFRESH_TIME: float = 0.3
const WAYPOINT_REACHED: float = 0.4 ## Close enough to this corner: on to the next one.

var _body: Node3D
var _large: bool = false
var _path: PackedVector3Array = PackedVector3Array()
var _next: int = 0
var _refresh_left: float = 0.0


## large = routes that keep further from obstacles, for bosses (MapNavigation.large_map).
func _init(body: Node3D, large: bool = false) -> void:
	_body = body
	_large = large
	# Spread out by enemy, so a wave doesn't ask for all its routes in the same frame.
	_refresh_left = fmod(float(body.get_instance_id() % 97) * 0.01, REFRESH_TIME)


## Flat direction to walk in now, to get to `point`.
func direction_to(point: Vector3, delta: float) -> Vector3:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH_TIME
		_ask_for_route(point)
	while _next < _path.size():
		var to_corner: Vector3 = _flat(_path[_next] - _body.global_position)
		if to_corner.length() > WAYPOINT_REACHED:
			return to_corner.normalized()
		_next += 1
	return _flat(point - _body.global_position).normalized()


func _ask_for_route(point: Vector3) -> void:
	var map: RID = _body.get_world_3d().navigation_map
	if _large and MapNavigation.large_map.is_valid() and NavigationServer3D.map_get_iteration_id(MapNavigation.large_map) > 0:
		map = MapNavigation.large_map
	_path = NavigationServer3D.map_get_path(map, _body.global_position, point, true)
	_next = 0


func _flat(offset: Vector3) -> Vector3:
	offset.y = 0.0
	return offset
