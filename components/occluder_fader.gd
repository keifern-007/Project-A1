class_name OccluderFader
extends Node
## Anything solid between the camera and the hero turns see-through (cliffs, tree walls, ruins), so
## nothing on a big map can hide them, in either camera mode. The shape stays visible, so it's never
## a surprise what's there. RetroView adds one to every run.
## Works from what you SEE, not collision: a tree only collides at its trunk, but its leaves block the view.
## Fadeable = every solid prop (StaticBody3D) and solid CSG shape on the map, except those in group
## "no_fade" (floors, ramps, map bounds). Props don't move, so their boxes are measured once.

const SEE_THROUGH: float = 0.7 ## 0 = solid, 1 = invisible.
const AIM_HEIGHT: float = 1.2 ## Aim at the hero's chest, not their feet.
const MAX_SIZE: float = 30.0 ## Metres. Anything wider (a floor, a whole map) is never faded.
const NEAR_HERO: float = 0.6 ## Stop the line this far short of the hero, so what they stand beside stays solid.

## The map to watch (set by RetroView). Scanning this, not "the first hero's viewport", means a map
## that's still being freed during a scene change can never be scanned by mistake.
var world: Node

var _candidates: Array = [] # [root Node3D, AABB in world space]
var _scanned: bool = false
var _faded: Dictionary = {} # Node3D -> true


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
	var now: Dictionary = {}
	for entry: Array in _candidates:
		var root: Node3D = entry[0]
		if is_instance_valid(root) and (entry[1] as AABB).intersects_segment(from, to):
			now[root] = true
	for root: Node3D in _faded:
		if not now.has(root) and is_instance_valid(root):
			_set_see_through(root, 0.0)
	for root: Node3D in now:
		if not _faded.has(root):
			_set_see_through(root, SEE_THROUGH)
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
		var box: AABB = _visual_box(root)
		# Floors and whole maps never count: a map's invisible Bounds would otherwise fade the entire map.
		if box.size != Vector3.ZERO and box.size.x <= MAX_SIZE and box.size.z <= MAX_SIZE:
			_candidates.append([root, box])


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
		if not node is Label3D:
			meshes.append(node)
	return meshes


func _set_see_through(root: Node3D, amount: float) -> void:
	for mesh: GeometryInstance3D in _meshes(root):
		mesh.transparency = amount
