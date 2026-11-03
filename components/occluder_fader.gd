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
const NEAR_HERO: float = 0.6 ## Stop the line this far short of the hero, so what they stand beside stays solid.

var _candidates: Array = [] # [root Node3D, AABB in world space]
var _scanned: bool = false
var _faded: Dictionary = {} # Node3D -> true


func _physics_process(_delta: float) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("players") as Node3D
	var camera: Camera3D = player.get_viewport().get_camera_3d() if player else null
	if camera == null:
		return
	if not _scanned:
		_scan(player.get_viewport())
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


## Every solid thing in the game world that can be faded, with its box.
func _scan(viewport: Viewport) -> void:
	_scanned = true
	var seen: Dictionary = {}
	for node: Node in viewport.find_children("*", "CollisionObject3D", true, false) + viewport.find_children("*", "CSGShape3D", true, false):
		var root: Node3D = _fade_root(node)
		if root == null or seen.has(root):
			continue
		seen[root] = true
		var box: AABB = _visual_box(root)
		if box.size != Vector3.ZERO:
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
	var parent: Node3D = node.get_parent() as Node3D
	return null if parent == null or parent.is_in_group("no_fade") else parent


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
