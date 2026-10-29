extends SkillEffect
## Hardens the caster: much less damage taken for a few seconds. A shell around them shows it
## (a shape, not just a color).

@export var damage_reduction: float = 0.6 ## 0.6 = hits deal 60% less.
@export var duration: float = 3.0

var _hurtbox: HurtboxComponent

@onready var shell: MeshInstance3D = $Shell


func _ready() -> void:
	_hurtbox = (caster as Player).hurtbox
	_hurtbox.damage_taken_multiplier *= 1.0 - damage_reduction
	shell.scale = Vector3.ONE * 0.3
	create_tween().tween_property(shell, "scale", Vector3.ONE, 0.15)
	get_tree().create_timer(duration, false, true).timeout.connect(_end)


func _physics_process(_delta: float) -> void:
	if is_instance_valid(caster):
		global_position = caster.global_position


func _end() -> void:
	if is_instance_valid(_hurtbox):
		_hurtbox.damage_taken_multiplier /= 1.0 - damage_reduction
	queue_free()
