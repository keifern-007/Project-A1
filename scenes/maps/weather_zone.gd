class_name WeatherZone
extends Node3D
## An area of a big map with its own weather (a cold cave, a sun-baked plateau). Drawn as an outline on
## the ground plan, not a physics shape: the hero's WeatherComponent asks contains() each frame.
## Keep the node unturned at the map's origin and write the outline in map metres (x, z).

const GROUP: StringName = &"weather_zones"

@export var weather: WeatherData
@export var outline: PackedVector2Array = PackedVector2Array() ## Map x, z. Any shape, not only convex.
@export var min_height: float = -10.0 ## Only counts between these heights (a shelf above a valley).
@export var max_height: float = 50.0


func _ready() -> void:
	add_to_group(GROUP)


func contains(point: Vector3) -> bool:
	var local: Vector3 = point - global_position
	if local.y < min_height or local.y > max_height:
		return false
	return Geometry2D.is_point_in_polygon(Vector2(local.x, local.z), outline)
