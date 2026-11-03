class_name OccluderFader
extends Node
## Anything solid between the camera and the hero turns see-through (cliffs, tree walls, ruins), so
## nothing on a big map can hide them, in either camera mode. The shape stays visible, so it's never
## a surprise what's there. RetroView adds one to every run.
## Works from what you SEE, not collision: a tree only collides at its trunk, but its leaves block the view.
## Fadeable = every solid prop (StaticBody3D) and solid CSG shape on the map, except those in group
## "no_fade" (floors, ramps, map bounds). Props don't move, so their boxes are measured once.
## Cave roofs (group "cave_roofs", looks only) aren't faded but hidden while in the way, still casting
## their shadow, so the cave stays dark and everything inside it is in plain view.
## Group "cutaway" (a mountain's rock, around tunnels): faded over the shoulder, but hidden like a roof
## in the isometric view, where a tunnel deep in the rock would sit behind several faded layers.

const SEE_THROUGH: float = 0.7 ## 0 = solid, 1 = invisible.
const AIM_HEIGHT: float = 1.2 ## Aim at the hero's chest, not their feet.
const MAX_SIZE: float = 30.0 ## Metres. Anything wider (a floor, a whole map) is never faded.
const NEAR_HERO: float = 0.6 ## Stop the line this far short of the hero, so what they stand beside stays solid.
const ROOF_GROUP: StringName = &"cave_roofs"
const CUTAWAY_GROUP: StringName = &"cutaway"

enum Kind { FADE, ROOF, CUTAWAY }
enum Look { SOLID, SEE_THROUGH, HIDDEN }

## The map to watch (set by RetroView). Scanning this, not "the first hero's viewport", means a map
## that's still being freed during a scene change can never be scanned by mistake.
var world: Node

var _candidates: Array = [] # [root Node3D, AABB in world space, Kind]
var _scanned: bool = false
var _faded: Dictionary = {} # Node3D -> Look


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(world) or not world.is_inside_tree():
		return
	var player: Node3D = _player()
	var camera: Camera3D = player.get_viewport().get_camera_3d() if player else null
	if camera == null:
		return
	if not _scanned:
		_scan(world)
	var from: Vector3 = camera.global_position
	var to: Vector3 = player.global_position + Vector3.UP * AIM_HEIGHT
	to -= (to - from).normalized() * NEAR_HERO
	var isometric: bool = camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	var now: Dictionary = {}
	for entry: Array in _candidates:
		var root: Node3D = entry[0]
		if is_instance_valid(root) and (entry[1] as AABB).intersects_segment(from, to):
			var kind: Kind = entry[2]
			now[root] = Look.HIDDEN if kind == Kind.ROOF or (kind == Kind.CUTAWAY and isometric) else Look.SEE_THROUGH
	for root: Node3D in _faded:
		if now.get(root, Look.SOLID) != _faded[root] and is_instance_valid(root):
			_show(root, Look.SOLID)
	for root: Node3D in now:
		if now[root] != _faded.get(root, Look.SOLID):
			_show(root, now[root])
	_faded = now


## This map's hero (not one from a map that's being unloaded).
func _player() -> Node3D:
	for node: Node in get_tree().get_nodes_in_group("players"):
		if world.is_ancestor_of(node):
			return node as Node3D
	return null


## Every solid thing on the map that can be faded, with its box.
func _scan(map: Node) -> void:
	_scanned = true
	var seen: Dictionary = {}
	for node: Node in map.find_children("*", "CollisionObject3D", true, false) + map.find_children("*", "CSGShape3D", true, false):
		var root: Node3D = _fade_root(node)
		if root == null or seen.has(root):
			continue
		seen[root] = true
		_add(root, Kind.CUTAWAY if root.is_in_group(CUTAWAY_GROUP) else Kind.FADE)
	# Cave roofs: any size (a cavern's roof is big), no collision needed.
	for roof: Node in get_tree().get_nodes_in_group(ROOF_GROUP):
		if roof is Node3D and map.is_ancestor_of(roof):
			_add(roof, Kind.ROOF)


func _add(root: Node3D, kind: Kind) -> void:
	var box: AABB = _visual_box(root)
	if box.size == Vector3.ZERO:
		return
	# Floors and whole maps never count: a map's invisible Bounds would otherwise fade the entire map.
	if kind == Kind.ROOF or (box.size.x <= MAX_SIZE and box.size.z <= MAX_SIZE):
		_candidates.append([root, box, kind])


## The node whose meshes should fade: a solid CSG shape, a prop body with its meshes, or the prop
## around a body (props whose body is a child). null = not something to fade.
func _fade_root(node: Node) -> Node3D:
	if node.is_in_group("no_fade"):
		return null
	if node is CSGShape3D:
		var shape: CSGShape3D = node
		return shape if shape.is_root_shape() and shape.use_collision else null
	if not node is StaticBody3D:
		return null
	for child: Node in node.get_children():
		if child is GeometryInstance3D:
			return node as Node3D
	# A body with no meshes of its own: fade the prop around it, but only if that prop has meshes
	# itself (camp-style props). Invisible walls (Bounds) fade nothing.
	var parent: Node3D = node.get_parent() as Node3D
	if parent == null or parent.is_in_group("no_fade"):
		return null
	for sibling: Node in parent.get_children():
		if sibling is GeometryInstance3D:
			return parent
	return null


func _visual_box(root: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for mesh: GeometryInstance3D in _meshes(root):
		var world_box: AABB = mesh.global_transform * mesh.get_aabb()
		box = world_box if first else box.merge(world_box)
		first = false
	return box


func _meshes(root: Node3D) -> Array[GeometryInstance3D]:
	var meshes: Array[GeometryInstance3D] = []
	if root is GeometryInstance3D:
		meshes.append(root)
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		# The parts of a CSG shape (the cuts in a mountain) aren't drawn by themselves, and their
		# boxes reach far past the result: only the shape they make counts.
		if node is Label3D or (node is CSGShape3D and not (node as CSGShape3D).is_root_shape()):
			continue
		meshes.append(node)
	return meshes


## Hidden = drawn as a shadow only, so what it shades stays dark. Only roofs and cutaway rock are ever
## hidden (they're made with shadows on), so putting shadows back on never changes another prop.
func _show(root: Node3D, look: Look) -> void:
	for mesh: GeometryInstance3D in _meshes(root):
		mesh.transparency = SEE_THROUGH if look == Look.SEE_THROUGH else 0.0
		if look == Look.HIDDEN:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		elif mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
