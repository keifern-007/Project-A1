extends Node3D
## Keeps turning at a steady speed: windmill sails, ducks paddling round a pond. Decoration only.

@export var axis: Vector3 = Vector3.UP
@export var speed: float = 0.5 ## Radians per second.


func _process(delta: float) -> void:
	rotate_object_local(axis.normalized(), speed * delta)
