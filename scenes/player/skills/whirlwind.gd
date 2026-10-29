extends SkillEffect
## Spins around the caster: the hitbox pulses a few times, hitting everything nearby each pulse.

@export var pulses: int = 3
@export var pulse_interval: float = 0.3
@export var pulse_active: float = 0.1
@export var spin_speed: float = 14.0 ## Radians per second, visual only.

@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var ring: MeshInstance3D = $Ring


func _ready() -> void:
	hitbox.damage = damage
	hitbox.active = false
	for i: int in pulses:
		get_tree().create_timer(i * pulse_interval + 0.01, false, true).timeout.connect(_pulse)
	get_tree().create_timer(pulses * pulse_interval, false, true).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if is_instance_valid(caster):
		global_position = caster.global_position
	ring.rotation.y += spin_speed * delta


func _pulse() -> void:
	hitbox.active = true
	GameFeel.shake(0.1)
	get_tree().create_timer(pulse_active, false, true).timeout.connect(_end_pulse)


func _end_pulse() -> void:
	hitbox.active = false
