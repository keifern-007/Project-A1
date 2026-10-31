extends SkillEffect
## Hits everything around the caster once, with an expanding ring.

@export var active_time: float = 0.15
@export var fade_time: float = 0.25
@export var shake: float = 0.35

@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var ring: MeshInstance3D = $Ring


func _ready() -> void:
	hitbox.damage = damage
	hitbox.element = element
	hitbox.active = true
	GameFeel.shake(shake)
	get_tree().create_timer(active_time, false, true).timeout.connect(_on_active_ended)

	ring.scale = Vector3.ONE * 0.2
	var tween: Tween = create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE, active_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "transparency", 1.0, fade_time)
	tween.tween_callback(queue_free)


func _on_active_ended() -> void:
	hitbox.active = false
