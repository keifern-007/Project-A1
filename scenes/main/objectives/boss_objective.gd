class_name BossObjective
extends Objective
## Kill N enemies to lure the boss out -> waves stop, boss spawns at the map's "boss_spawns"
## marker (leftover enemies poof away: it's a solo fight) -> defeating it drops the boss-exclusive material and completes the objective.

const PREP_KEY: String = "OBJ_BOSS_PREP"

var _kills: int = 0
var _boss_spawned: bool = false
var _spawner: WaveSpawner


func _ready() -> void:
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	if data.kills_before_boss <= 0:
		_spawn_boss.call_deferred()
		return
	_report_progress(0, data.kills_before_boss, PREP_KEY)
	_spawner = _setup_spawner(0)


func _on_enemy_killed(_enemy: Node) -> void:
	if _boss_spawned:
		return
	_kills += 1
	_report_progress(_kills, data.kills_before_boss, PREP_KEY)
	if _kills >= data.kills_before_boss:
		_spawn_boss()


func _spawn_boss() -> void:
	_boss_spawned = true
	if _spawner:
		_spawner.stop()
		_spawner.despawn_all()
	var point: Node3D = get_tree().get_first_node_in_group("boss_spawns")
	if point == null:
		push_error("BossObjective: this map has no Marker3D in group 'boss_spawns'.")
		return
	var boss: Node3D = data.boss_scene.instantiate()
	point.get_parent().add_child(boss)
	boss.global_position = point.global_position
	_report_progress(0, 1)


func _on_boss_defeated(_boss: Node) -> void:
	if data.boss_drop:
		EventBus.material_obtained.emit(data.boss_drop, data.boss_drop_amount)
	_report_progress(1, 1)
	_complete()
