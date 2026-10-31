class_name Objective
extends Node
## Runs one objective during a run. Subclasses decide what "done" means and call _complete().
## Create with Objective.create(data), then add it to the tree to start it.

signal completed

var data: ObjectiveData


static func create(objective_data: ObjectiveData) -> Objective:
	var objective: Objective
	match objective_data.type:
		ObjectiveData.Type.HORDE:
			objective = HordeObjective.new()
		ObjectiveData.Type.BOSS:
			objective = BossObjective.new()
		ObjectiveData.Type.GATHER:
			objective = GatherObjective.new()
		_:
			push_error("Objective type not built yet: %s" % ObjectiveData.Type.keys()[objective_data.type])
			return null
	objective.data = objective_data
	objective.name = "Objective"
	return objective


## The HUD shows "<objective name>  current/target". name_key overrides the label for a sub-step.
func _report_progress(current: int, target: int, name_key: String = "") -> void:
	EventBus.objective_progress.emit(name_key if name_key != "" else data.name_key, current, target)


## Configures the map's WaveSpawner from data and starts it. max_waves 0 = endless.
func _setup_spawner(max_waves: int) -> WaveSpawner:
	var spawner: WaveSpawner = get_tree().get_first_node_in_group("wave_spawners")
	if spawner == null:
		push_error("%s: this map has no WaveSpawner." % name)
		return null
	spawner.first_wave_size = data.first_wave_size
	spawner.wave_size_growth = data.wave_size_growth
	spawner.health_growth_per_wave = data.health_growth_per_wave
	spawner.max_waves = max_waves
	var map_data: MapData = GameState.map as MapData
	if map_data and not map_data.enemy_pool.is_empty():
		spawner.enemy_pool = map_data.enemy_pool
	spawner.start()
	return spawner


func _complete() -> void:
	completed.emit()
