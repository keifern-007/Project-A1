class_name LobbedShot
extends Node3D
## An enemy throw that arcs to a spot on the ground and hits everything in a small circle there.
## The telegraph is shape, not color: a ring marks where it lands, and a disc grows inside it
## until it fills the ring at the moment of impact. Its hitbox is on "hits_player".

const LINGER_FRAMES: int = 2 ## Physics frames the hitbox stays live so hurtboxes see it.
const ELEMENT_TINTS: Dictionary = {
	Element.Type.PHYSICAL: Color(0.5, 0.48, 0.45),
	Element.Type.ICE: Color(0.7, 0.9, 1.0),
	Element.Type.POISON: Color(0.55, 0.62, 0.3),
	Element.Type.FIRE: Color(1.0, 0.5, 0.2),
}

@export var flight_time: float = 0.9
@export var arc_height: float = 3.0
@export var radius: float = 1.1 ## Must match the hitbox shape and the ring mesh.

var _start: Vector3
var _landing: Vector3
var _time: float = 0.0
var _landed: bool = false
var _damage: int = 5
var _element: Element.Type = Element.Type.PHYSICAL
var _knockback: float = 4.0

@onready var rock: MeshInstance3D = $Rock
@onready var marker: Node3D = $Marker
@onready var fill: MeshInstance3D = $Marker/Fill
@onready var hitbox: HitboxComponent = $HitboxComponent


## Call before adding to the tree. Positions are global.
func setup(from: Vector3, to: Vector3, damage: int, element: Element.Type, knockback: float) -> void:
	_start = from
	_landing = Vector3(to.x, 0.0, to.z)
	_damage = damage
	_element = element
	_knockback = knockback


func _ready() -> void:
	top_level = true
	global_position = _start
	hitbox.damage = _damage
	hitbox.element = _element
	hitbox.knockback = _knockback
	hitbox.active = false
	hitbox.top_level = true
	hitbox.global_position = _landing
	marker.top_level = true
	marker.global_position = _landing + Vector3.UP * 0.05
	fill.scale = Vector3(0.01, 1.0, 0.01)
	var material: StandardMaterial3D = rock.get_surface_override_material(0).duplicate()
	material.albedo_color = ELEMENT_TINTS.get(hitbox.element, ELEMENT_TINTS[Element.Type.PHYSICAL])
	rock.set_surface_override_material(0, material)


func _physics_process(delta: float) -> void:
	if _landed:
		return
	_time += delta
	var t: float = minf(_time / flight_time, 1.0)
	rock.global_position = _start.lerp(_landing, t) + Vector3.UP * arc_height * 4.0 * t * (1.0 - t)
	fill.scale = Vector3(t, 1.0, t)
	if t >= 1.0:
		_land()


func _land() -> void:
	_landed = true
	rock.visible = false
	hitbox.active = true
	for i: int in LINGER_FRAMES:
		await get_tree().physics_frame
	hitbox.active = false
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(marker, "scale", Vector3(1.4, 1.0, 1.4), 0.2)
	tween.tween_property(fill, "transparency", 1.0, 0.2)
	tween.chain().tween_callback(queue_free)
