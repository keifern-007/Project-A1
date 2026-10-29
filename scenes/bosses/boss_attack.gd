class_name BossAttack
extends Node3D
## One boss move: telegraph (pose + ground marker) -> active hitbox -> recovery (punish window).
## Expects a HitboxComponent and a Marker (flat mesh showing where it will hit) as children.
## The boss decides when to use it and drives the timing; this node only holds data and visuals.

enum Pose { OVERHEAD, SWEEP, LEAP }

@export var pose: Pose = Pose.OVERHEAD
@export var damage: int = 20
@export var knockback: float = 10.0
@export var shake: float = 0.4

@export_group("Timing")
@export var windup: float = 1.0 ## Telegraph time; the dodge window is at its very end.
@export_range(0.0, 1.0) var track_fraction: float = 0.5 ## Part of the windup where the boss still turns to follow you.
@export var active_time: float = 0.15
@export var recovery: float = 1.0 ## Punish window.
@export var cooldown: float = 0.0

@export_group("Selection")
@export var min_range: float = 0.0
@export var max_range: float = 4.0
@export var weight: float = 1.0 ## Higher = picked more often when several attacks fit.

var cooldown_left: float = 0.0

@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var marker: MeshInstance3D = $Marker


func _ready() -> void:
	hitbox.damage = damage
	hitbox.knockback = knockback
	hitbox.active = false
	marker.visible = false


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func is_usable(distance: float) -> bool:
	return cooldown_left == 0.0 and distance >= min_range and distance <= max_range


## Fades the ground marker in over the windup (a steady fade, never a strobe).
func show_telegraph(duration: float) -> void:
	marker.visible = true
	marker.transparency = 1.0
	create_tween().tween_property(marker, "transparency", 0.35, duration * 0.5)


## For markers that aren't attached to the boss (e.g. a leap's landing spot).
func place_marker(world_position: Vector3) -> void:
	marker.global_position = world_position + Vector3(0.0, 0.05, 0.0)


func strike() -> void:
	marker.visible = false
	hitbox.active = true
	cooldown_left = cooldown
	GameFeel.shake(shake)


func end_strike() -> void:
	hitbox.active = false


func cancel() -> void:
	marker.visible = false
	hitbox.active = false
