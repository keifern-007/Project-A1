extends SkillEffect
## Fires a fan of projectiles toward `direction`: Arcane Barrage (bolts), Fan of Knives (knives).

@export var projectile_scene: PackedScene ## Root must be a Projectile.
@export var count: int = 3
@export var spread_degrees: float = 15.0 ## Angle between neighbouring projectiles.


func _ready() -> void:
	_fire.call_deferred() # The world is still adding us; add the projectiles right after.


func _fire() -> void:
	for i: int in count:
		var angle: float = deg_to_rad(spread_degrees * (i - (count - 1) / 2.0))
		var projectile: Projectile = projectile_scene.instantiate()
		projectile.damage = damage
		projectile.element = element
		projectile.direction = direction.rotated(Vector3.UP, angle)
		projectile.caster = caster
		get_parent().add_child(projectile)
		projectile.global_position = caster.global_position
	queue_free()
