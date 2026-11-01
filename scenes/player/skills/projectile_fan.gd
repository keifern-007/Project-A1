extends SkillEffect
## Fires a fan of projectiles toward `direction`: Arcane Barrage (bolts), Fan of Knives (knives).
## A target only takes one hit per hurtbox cooldown (enemies: 0.2 s), so projectiles landing together
## count once. A `fire_interval` above that lets every projectile of the fan hurt a single target.

@export var projectile_scene: PackedScene ## Root must be a Projectile.
@export var count: int = 3
@export var spread_degrees: float = 15.0 ## Angle between neighbouring projectiles.
@export var fire_interval: float = 0.0 ## Seconds between projectiles. 0 = all at once.

var _fired: int = 0
var _next_shot_in: float = 0.0


func _physics_process(delta: float) -> void:
	_next_shot_in -= delta
	while _fired < count and _next_shot_in <= 0.0:
		_fire_next()
		_next_shot_in += fire_interval
	if _fired >= count or not is_instance_valid(caster):
		queue_free()


func _fire_next() -> void:
	if not is_instance_valid(caster):
		_fired = count
		return
	var angle: float = deg_to_rad(spread_degrees * (_fired - (count - 1) / 2.0))
	var projectile: Projectile = projectile_scene.instantiate()
	projectile.damage = damage
	projectile.element = element
	projectile.direction = direction.rotated(Vector3.UP, angle)
	projectile.caster = caster
	get_parent().add_child(projectile)
	projectile.global_position = caster.global_position
	_fired += 1
