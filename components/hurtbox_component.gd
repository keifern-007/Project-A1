class_name HurtboxComponent
extends Area3D
## A zone that can be hurt. Its collision MASK decides which hitboxes it reacts to.
## Standing in a hitbox keeps hurting you, once per hit_cooldown.

signal hurt(amount: int, hitbox: HitboxComponent)

@export var health: HealthComponent
## Optional. Defense reduces incoming damage.
@export var stats: StatsComponent
## Mercy time after being hit, so overlapping hitboxes don't shred you in one frame.
@export var hit_cooldown: float = 0.5

## Scales every hit before defense (challenge difficulty on players). 1.0 = normal.
@export var damage_taken_multiplier: float = 1.0

## Set by the owner (e.g. during a dodge) to ignore all hits.
var invulnerable: bool = false

var _cooldown_left: float = 0.0


func _ready() -> void:
	monitorable = false


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if invulnerable or _cooldown_left > 0.0 or not monitoring or health == null or health.is_dead:
		return
	for area: Area3D in get_overlapping_areas():
		var hitbox: HitboxComponent = area as HitboxComponent
		if hitbox and hitbox.active:
			_take_hit(hitbox)
			return


func _take_hit(hitbox: HitboxComponent) -> void:
	var defense: int = stats.defense if stats else 0
	var amount: int = Combat.calculate_damage(roundi(hitbox.damage * damage_taken_multiplier), defense)
	_cooldown_left = hit_cooldown
	health.take_damage(amount)
	hurt.emit(amount, hitbox)
