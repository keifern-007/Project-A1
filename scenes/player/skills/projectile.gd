class_name Projectile
extends SkillEffect
## Flies straight along `direction` and stops at the first enemy or wall it touches.
## The enemy's hurtbox takes the hit from our HitboxComponent. Used by Magic Bolt and Arcane Barrage.

@export var speed: float = 18.0
@export var max_distance: float = 12.0

var _travelled: float = 0.0
var _stopped: bool = false

@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var sensor: Area3D = $Sensor


func _ready() -> void:
	hitbox.damage = damage
	direction.y = 0.0
	direction = direction.normalized()
	rotation.y = atan2(-direction.x, -direction.z)
	sensor.body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _stopped:
		return
	var step: float = speed * delta
	global_position += direction * step
	_travelled += step
	if _travelled >= max_distance:
		queue_free()


# Stop on contact, but stay a couple of physics frames so the enemy's hurtbox sees the hit.
func _on_body_entered(_body: Node3D) -> void:
	if _stopped:
		return
	_stopped = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	queue_free()
