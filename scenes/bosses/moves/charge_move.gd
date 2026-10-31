class_name ChargeMove
extends BossMove
## The boss hurls itself in a straight line (Belly Slide). An arrow as long as the charge grows on
## the ground during the windup (it follows the boss's turning, then locks). While charging the boss
## passes through heroes (its hitbox does the damage); hitting a wall ends it in a long stun.
## Children: HitboxComponent and Arrow (with Shaft and Head meshes).

const WORLD_ONLY_MASK: int = 1
const MIN_CRASH_DISTANCE: float = 1.0 ## Starting right against a wall doesn't count as a crash.

@export var speed: float = 15.0
@export var distance: float = 18.0
@export var crash_stun: float = 2.5 ## Extra punish window when it slams into a wall.

var _dir: Vector3 = Vector3.FORWARD
var _travelled: float = 0.0
var _saved_mask: int = 0
var _arrow_tween: Tween

@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var arrow: Node3D = $Arrow


func _ready() -> void:
	moves_boss = true
	_prepare_hitbox(hitbox)
	var shaft: Node3D = arrow.get_node("Shaft")
	shaft.scale.z = distance
	shaft.position.z = -distance * 0.5
	(arrow.get_node("Head") as Node3D).position.z = -distance
	arrow.visible = false


func start(_boss: Boss, _target: Node3D, real_windup: float) -> void:
	arrow.visible = true
	arrow.scale = Vector3(1.0, 1.0, 0.05)
	if _arrow_tween:
		_arrow_tween.kill()
	_arrow_tween = create_tween()
	_arrow_tween.tween_property(arrow, "scale:z", 1.0, real_windup)


func strike(boss: Boss) -> void:
	super.strike(boss)
	arrow.visible = false
	_dir = boss.forward()
	_travelled = 0.0
	_saved_mask = boss.collision_mask
	boss.collision_mask = WORLD_ONLY_MASK
	hitbox.active = true


func active_process(boss: Boss, _time: float, delta: float) -> bool:
	var step: float = speed * boss.speed_scale
	boss.velocity.x = _dir.x * step
	boss.velocity.z = _dir.z * step
	_travelled += step * delta
	return _travelled >= distance


func after_move(boss: Boss) -> void:
	if boss.is_on_wall() and _travelled >= MIN_CRASH_DISTANCE:
		boss.crash(crash_stun)


func finish(boss: Boss) -> void:
	hitbox.active = false
	boss.collision_mask = _saved_mask
	boss.velocity.x = 0.0
	boss.velocity.z = 0.0


func cancel() -> void:
	hitbox.active = false
	arrow.visible = false
