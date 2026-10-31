class_name SlowZone
extends Area3D
## Ground that drags heroes down while they stand in it (quicksand). Mask = player bodies (layer 2).
## Each zone is its own slow source, so overlapping zones and leaving one of them both work.
## A slowly turning swirl shows the area (shape and motion, not color).

@export var speed_multiplier: float = 0.45
@export var swirl_speed: float = 1.2 ## Radians per second.

var _inside: Array[Node] = []

@onready var swirl: Node3D = get_node_or_null("Swirl")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if swirl:
		swirl.rotation.y += swirl_speed * delta


func _exit_tree() -> void:
	for body: Node in _inside:
		if is_instance_valid(body):
			body.call("set_speed_modifier", _source(), 1.0)
	_inside.clear()


func _on_body_entered(body: Node) -> void:
	if body.has_method("set_speed_modifier") and not _inside.has(body):
		_inside.append(body)
		body.call("set_speed_modifier", _source(), speed_multiplier)


func _on_body_exited(body: Node) -> void:
	if _inside.has(body):
		_inside.erase(body)
		body.call("set_speed_modifier", _source(), 1.0)


func _source() -> StringName:
	return StringName("slow_zone_%d" % get_instance_id())
