class_name DropZone
extends Node3D
## One impact spot of an AreaRainMove. Telegraph = a ring on the ground with a disc filling it as the
## impact nears, plus the falling object itself in the last moments (shape and motion, not color).
## On impact: hits players inside (2 physics frames), then optionally leaves an obstacle for a while.

const HIT_FRAMES: int = 2
const FALL_TIME: float = 0.3 ## The falling object is visible for this long before impact.
const FALL_HEIGHT: float = 9.0
const SINK_TIME: float = 0.5

var _radius: float = 1.6
var _delay: float = 1.0
var _damage: int = 15
var _element: Element.Type = Element.Type.PHYSICAL
var _knockback: float = 8.0
var _obstacle_scene: PackedScene
var _obstacle_time: float = 6.0
var _time: float = 0.0
var _fired: bool = false
var _obstacle: Node3D
var show_falling: bool = true ## False = no falling object, just the ring (shockwaves, quicksand).

@onready var marker: Node3D = $Marker
@onready var fill: MeshInstance3D = $Marker/Fill
@onready var falling: Node3D = $Falling
@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var hit_shape: CollisionShape3D = $HitboxComponent/CollisionShape3D


## Call before adding to the tree. delay = seconds until impact.
func setup(spot: Vector3, radius: float, delay: float, damage: int, element: Element.Type,
		knockback: float, obstacle_scene: PackedScene, obstacle_time: float) -> void:
	position = spot
	_radius = radius
	_delay = maxf(delay, 0.1)
	_damage = damage
	_element = element
	_knockback = knockback
	_obstacle_scene = obstacle_scene
	_obstacle_time = obstacle_time


func _ready() -> void:
	marker.scale = Vector3(_radius, 1.0, _radius) # Ring and fill meshes are built for radius 1.
	fill.scale = Vector3(0.01, 1.0, 0.01)
	falling.visible = false
	var shape: CylinderShape3D = (hit_shape.shape as CylinderShape3D).duplicate()
	shape.radius = _radius
	hit_shape.shape = shape
	hitbox.damage = _damage
	hitbox.element = _element
	hitbox.knockback = _knockback
	hitbox.active = false


func _physics_process(delta: float) -> void:
	if _fired:
		return
	_time += delta
	var t: float = minf(_time / _delay, 1.0)
	fill.scale = Vector3(t, 1.0, t)
	var fall_left: float = _delay - _time
	if show_falling and fall_left <= FALL_TIME:
		falling.visible = true
		falling.position.y = FALL_HEIGHT * maxf(fall_left, 0.0) / FALL_TIME
	if t >= 1.0:
		_impact()


func _impact() -> void:
	_fired = true
	falling.visible = false
	marker.visible = false
	hitbox.active = true
	GameFeel.shake(0.15)
	for i: int in HIT_FRAMES:
		await get_tree().physics_frame
	hitbox.active = false
	if _obstacle_scene == null:
		queue_free()
		return
	_obstacle = _obstacle_scene.instantiate()
	add_child(_obstacle)
	await get_tree().create_timer(_obstacle_time, false).timeout
	var sink: Tween = create_tween()
	sink.tween_property(_obstacle, "position:y", -3.0, SINK_TIME)
	sink.tween_callback(queue_free)


## Called off before impact (the boss died). Obstacles already standing stay until they expire.
func cancel() -> void:
	if not _fired:
		queue_free()
