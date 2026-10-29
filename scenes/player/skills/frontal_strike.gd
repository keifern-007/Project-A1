extends SkillEffect
## A hit (or a quick series of hits) in front of the caster: Shield Bash, Cleave, Haymaker, Flurry.
## The scene sets the hitbox shape, knockback and look; these numbers set the timing.

@export var hits: int = 1
## Seconds between hits when hits > 1. Keep it above enemies' hurtbox hit_cooldown (0.2) or hits get eaten.
@export var hit_interval: float = 0.12
@export var active_time: float = 0.12 ## How long each hit's hitbox is live.
@export var fade_time: float = 0.2
@export var shake: float = 0.25
@export var lunge: float = 0.6 ## How far the visual pushes forward on each hit.

var _slab_start_z: float = 0.0

@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var slab: MeshInstance3D = $Slab


func _ready() -> void:
	rotation.y = atan2(-direction.x, -direction.z)
	hitbox.damage = damage
	hitbox.active = false
	_slab_start_z = slab.position.z
	for i: int in hits:
		get_tree().create_timer(i * hit_interval + 0.01, false, true).timeout.connect(_hit)
	var last_hit_end: float = (hits - 1) * hit_interval + 0.01 + active_time
	var tween: Tween = create_tween()
	tween.tween_interval(last_hit_end)
	tween.tween_property(slab, "transparency", 1.0, fade_time)
	tween.tween_callback(queue_free)


func _hit() -> void:
	hitbox.active = true
	GameFeel.shake(shake)
	slab.position.z = _slab_start_z
	create_tween().tween_property(slab, "position:z", _slab_start_z - lunge, active_time)
	get_tree().create_timer(active_time, false, true).timeout.connect(_end_hit)


func _end_hit() -> void:
	hitbox.active = false
