class_name PoisonCloud
extends Node3D
## What a Puffcap leaves behind: a burst (full damage, knockback) and then a lingering cloud
## that keeps poisoning whoever stands in it (once per hurtbox cooldown). Hits players only.
## Its edge is shown by a ring on the ground, so the danger zone reads by shape, not color.

const BURST_FRAMES: int = 2 ## Physics frames the burst damage is live.
const FADE_TIME: float = 0.5

@export var duration: float = 4.0

var _burst_damage: int = 12
var _cloud_damage: int = 3

@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var puffs: Node3D = $Puffs


## Call before adding to the tree.
func setup(burst_damage: int, cloud_damage: int, lingers_for: float) -> void:
	_burst_damage = burst_damage
	_cloud_damage = maxi(cloud_damage, 1)
	duration = lingers_for


func _ready() -> void:
	hitbox.element = Element.Type.POISON
	hitbox.damage = _burst_damage
	hitbox.active = true
	puffs.scale = Vector3.ONE * 0.3
	create_tween().tween_property(puffs, "scale", Vector3.ONE, 0.25)
	GameFeel.shake(0.2)
	for i: int in BURST_FRAMES:
		await get_tree().physics_frame
	hitbox.damage = _cloud_damage
	hitbox.knockback = 0.0
	await get_tree().create_timer(duration, false).timeout
	hitbox.active = false
	var fade: Tween = create_tween().set_parallel()
	for puff: Node in puffs.get_children():
		if puff is GeometryInstance3D:
			fade.tween_property(puff, "transparency", 1.0, FADE_TIME)
	fade.chain().tween_callback(queue_free)
