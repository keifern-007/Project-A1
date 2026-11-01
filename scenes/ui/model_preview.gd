class_name ModelPreview
extends SubViewportContainer
## A small turning 3D view for the UI: an item (Forge) or a hero wearing their gear (cards, Gear Rack).
## Rendered at low resolution like the game itself. It has its own 3D world, so nothing leaks into the map.

const TURN_SPEED: float = 0.8 ## Radians per second.
const PADDING: float = 1.25 ## Leaves a little room around the model.

var _content: Node3D
var _animator: HeroAnimator

@onready var viewport: SubViewport = %Viewport
@onready var pivot: Node3D = %Pivot
@onready var camera: Camera3D = %PreviewCamera


func _process(delta: float) -> void:
	pivot.rotation.y += TURN_SPEED * delta


## Shows one item. Items without a model show nothing.
func show_item(item: ItemData) -> void:
	_clear()
	var scene: PackedScene = item.model() if item else null
	if scene == null:
		return
	_content = scene.instantiate()
	pivot.add_child(_content)
	_frame(_content)


## Shows a hero's model, wearing their saved loadout, moving through their idle.
func show_hero(character: CharacterData) -> void:
	_clear()
	if character == null or character.rig == null:
		return
	var rig: HeroRig = character.rig.instantiate()
	pivot.add_child(rig)
	rig.wear_loadout(str(character.id))
	_animator = HeroAnimator.new()
	rig.add_child(_animator)
	_animator.setup(rig)
	_content = rig
	_frame.call_deferred(rig)


func _clear() -> void:
	if _content:
		_content.queue_free()
	_content = null
	_animator = null


# Centers the model and zooms to fit it, whatever its size.
func _frame(model: Node3D) -> void:
	if not is_instance_valid(model):
		return
	model.position = Vector3.ZERO
	var bounds: AABB = _bounds_of(model, pivot.global_transform.affine_inverse())
	model.position = -bounds.get_center()
	# The camera looks down at an angle, so the largest side is a safe measure for any turn.
	camera.size = maxf(bounds.size.length() * PADDING * 0.68, 0.5)


func _bounds_of(node: Node, to_pivot: Transform3D) -> AABB:
	var bounds: AABB = AABB()
	var found: bool = false
	for child: Node in node.get_children():
		var part: AABB = _bounds_of(child, to_pivot)
		if child is MeshInstance3D:
			var mesh_bounds: AABB = to_pivot * (child as MeshInstance3D).global_transform * (child as MeshInstance3D).get_aabb()
			part = part.merge(mesh_bounds) if part.size != Vector3.ZERO else mesh_bounds
		if part.size != Vector3.ZERO:
			bounds = bounds.merge(part) if found else part
			found = true
	return bounds
