extends SkillEffect
## Heals the caster a share of their max HP, spread over a few seconds (the wand's support skill).
## A ring of petals around them shows it's active.

@export var heal_fraction: float = 0.25 ## 0.25 = 25% of max HP in total.
@export var duration: float = 3.0
@export var ticks: int = 6
@export var spin_speed: float = 2.0 ## Radians per second, visual only.

var _health: HealthComponent
var _total: int = 0
var _healed: int = 0
var _ticks_done: int = 0

@onready var ring: MeshInstance3D = $Ring


func _ready() -> void:
	_health = (caster as Player).health
	_total = maxi(roundi(_health.max_health * heal_fraction), 1)
	for i: int in ticks:
		get_tree().create_timer((i + 1) * duration / ticks, false, true).timeout.connect(_tick)
	get_tree().create_timer(duration + 0.05, false, true).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if is_instance_valid(caster):
		global_position = caster.global_position
	ring.rotation.y += spin_speed * delta


## Each tick heals up to its share of the total, so rounding never loses HP (3.25 -> 3, 4, 3...).
func _tick() -> void:
	_ticks_done += 1
	var amount: int = roundi(float(_total) * _ticks_done / ticks) - _healed
	_healed += amount
	if is_instance_valid(_health):
		_health.heal(amount)
