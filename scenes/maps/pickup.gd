class_name Pickup
extends Area3D
## Loot on the ground: XP, a material, or a booster (set one). Each kind has its own shape
## (diamond / cube / plus / cone) so it reads without color. Drifts to a nearby player.

const MAGNET_ACCEL: float = 30.0
const COLLECT_DISTANCE: float = 0.8
const LIFETIME: float = 40.0
const SPIN_SPEED: float = 3.0
const VACUUM_START_SPEED: float = 10.0

@export var xp: int = 0
@export var drop_material: MaterialData
@export var booster: BoosterData
@export var amount: int = 1

var _target: Player = null
var _speed: float = 0.0
var _age: float = 0.0

@onready var visual: Node3D = $Visual


func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	$Visual/XpGem.visible = xp > 0
	$Visual/MaterialCube.visible = drop_material != null
	$Visual/HealPlus.visible = booster != null and booster.effect == BoosterData.Effect.HEAL
	$Visual/BoostCone.visible = booster != null and booster.effect == BoosterData.Effect.DAMAGE_UP
	if drop_material:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = drop_material.color
		($Visual/MaterialCube as MeshInstance3D).material_override = mat


func _physics_process(delta: float) -> void:
	_age += delta
	visual.rotation.y += SPIN_SPEED * delta
	visual.position.y = 0.4 + sin(_age * 3.0) * 0.08
	if _target == null or not _target.is_alive():
		_target = null
		if _age > LIFETIME:
			_expire()
		return
	_speed += MAGNET_ACCEL * delta
	var to_target: Vector3 = _target.global_position + Vector3(0.0, 0.5, 0.0) - global_position
	if to_target.length() < COLLECT_DISTANCE:
		_collect()
		return
	global_position += to_target.normalized() * minf(_speed * delta, to_target.length())


## Pull this pickup to a player from anywhere (e.g. the end-of-mission loot vacuum).
func attract(player: Player) -> void:
	_target = player
	_speed = maxf(_speed, VACUUM_START_SPEED)


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if _target == null and player and player.is_alive():
		_target = player


func _collect() -> void:
	set_physics_process(false)
	_target.collect(self)
	queue_free()


func _expire() -> void:
	set_physics_process(false)
	var tween: Tween = create_tween()
	tween.tween_property(visual, "scale", Vector3.ZERO, 0.4)
	tween.tween_callback(queue_free)
