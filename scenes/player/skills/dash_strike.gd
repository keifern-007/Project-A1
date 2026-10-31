extends SkillEffect
## Dashes the caster forward; everything it passes through gets hit.

@export var dash_speed: float = 22.0
@export var dash_time: float = 0.25

@onready var hitbox: HitboxComponent = $HitboxComponent


func _ready() -> void:
	hitbox.damage = damage
	hitbox.element = element
	(caster as Player).dash(direction, dash_speed, dash_time, false)
	get_tree().create_timer(dash_time + 0.05, false, true).timeout.connect(queue_free)


func _physics_process(_delta: float) -> void:
	if is_instance_valid(caster):
		global_position = caster.global_position
