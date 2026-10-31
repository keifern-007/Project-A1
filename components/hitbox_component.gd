class_name HitboxComponent
extends Area3D
## A zone that deals damage (a sword swing, a projectile, a trap).
## Its collision LAYER decides who it can hurt: "hits_player" or "hits_enemy".

@export var damage: int = 10
## How hard this pushes whatever it hits, away from the hitbox's origin.
@export var knockback: float = 0.0
@export var element: Element.Type = Element.Type.PHYSICAL
## Turn on only during an attack's active frames. Traps just leave it on.
@export var active: bool = true:
	set(value):
		active = value
		set_deferred("monitorable", value)


func _ready() -> void:
	monitoring = false
	monitorable = active
