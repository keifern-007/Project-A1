class_name ConeMove
extends BossMove
## A breath/spray in a wedge in front of the boss that lasts active_time (Frost Breath).
## The wedge fades in on the ground during the windup, then fills with mist while it hits
## (once per hurtbox cooldown, so Ice stacks Chill: three in a row freeze). It can sweep sideways.
## The hitbox shape and both meshes are built from length and half_angle, so tweak those freely.
## A sweeping cone telegraphs where the sweep STARTS (the marker is turned there) and, with an
## optional Marker/SweepHint child, an arrowhead at the tip pointing the way it will turn.
## Thin + long + big sweep = a rotating beam (the Sun-Eaten King's Curse Beam).
## Children: HitboxComponent (with a CollisionShape3D), Marker and Mist (MeshInstance3D).

const ARC_STEPS: int = 8
const HEIGHT: float = 2.4

@export var length: float = 8.0
@export var half_angle_degrees: float = 28.0
@export var sweep_degrees: float = 0.0 ## Total sideways sweep while active.
@export var phase_two_sweep_degrees: float = 80.0
@export var random_sweep_direction: bool = false ## Picked with the run RNG; the hint shows which.

var _sweep: float = 0.0
var _sign: float = 1.0
var _base_yaw: float = 0.0

@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var marker: MeshInstance3D = $Marker
@onready var mist: MeshInstance3D = $Mist


func _ready() -> void:
	_prepare_hitbox(hitbox)
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shape.points = _wedge_points()
	(hitbox.get_node("CollisionShape3D") as CollisionShape3D).shape = shape
	var mesh: ArrayMesh = _wedge_mesh()
	marker.mesh = mesh
	mist.mesh = mesh
	marker.visible = false
	mist.visible = false
	var hint: MeshInstance3D = marker.get_node_or_null("SweepHint")
	if hint:
		hint.mesh = _arrowhead_mesh()
		hint.visible = false


func start(boss: Boss, _target: Node3D, real_windup: float) -> void:
	_sweep = deg_to_rad(phase_two_sweep_degrees if boss.phase >= 2 else sweep_degrees)
	_sign = 1.0
	if random_sweep_direction and GameState.rng.randf() < 0.5:
		_sign = -1.0
	marker.rotation.y = -_sign * _sweep * 0.5 # Show where the sweep starts.
	var hint: MeshInstance3D = marker.get_node_or_null("SweepHint")
	if hint:
		hint.visible = _sweep > 0.0
		hint.position = Vector3(0.0, 0.08, -length)
		hint.rotation.y = _sign * PI * 0.5 # Points along the turn.
	_fade_in(marker, real_windup, 0.5)


func strike(boss: Boss) -> void:
	super.strike(boss)
	marker.visible = false
	marker.rotation.y = 0.0
	mist.visible = true
	hitbox.active = true
	_base_yaw = boss.rotation.y
	boss.rotation.y = _base_yaw - _sign * _sweep * 0.5


func active_process(boss: Boss, time: float, _delta: float) -> bool:
	if _sweep > 0.0:
		boss.rotation.y = _base_yaw - _sign * _sweep * 0.5 + _sign * _sweep * minf(time / active_time, 1.0)
	return false


func finish(_boss: Boss) -> void:
	hitbox.active = false
	mist.visible = false


func cancel() -> void:
	hitbox.active = false
	marker.visible = false
	mist.visible = false


func _arc_point(i: int, y: float) -> Vector3:
	var angle: float = deg_to_rad(lerpf(-half_angle_degrees, half_angle_degrees, float(i) / ARC_STEPS))
	return Vector3(sin(angle) * length, y, -cos(angle) * length)


func _wedge_points() -> PackedVector3Array:
	var points: PackedVector3Array = [Vector3(0.0, 0.1, 0.0), Vector3(0.0, HEIGHT, 0.0)]
	for i: int in ARC_STEPS + 1:
		points.append(_arc_point(i, 0.1))
		points.append(_arc_point(i, HEIGHT))
	return points


## A flat triangle pointing -Z (the sweep-direction arrowhead).
func _arrowhead_mesh() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0.0, 0.0, -1.2), Vector3(0.8, 0.0, 0.5), Vector3(-0.8, 0.0, 0.5)])
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A flat fan on the ground (double-sided).
func _wedge_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = []
	for i: int in ARC_STEPS:
		vertices.append(Vector3(0.0, 0.06, 0.0))
		vertices.append(_arc_point(i, 0.06))
		vertices.append(_arc_point(i + 1, 0.06))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
