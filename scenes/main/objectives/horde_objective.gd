class_name HordeObjective
extends Objective
## Survive N waves. Configures the map's WaveSpawner from the ObjectiveData, then starts it.

var _spawner: WaveSpawner


func _ready() -> void:
	_report_progress(0, data.waves_to_survive)
	_spawner = _setup_spawner(data.waves_to_survive)
	if _spawner:
		_spawner.wave_started.connect(_on_wave_started)
		_spawner.wave_cleared.connect(_on_wave_cleared)


func _on_wave_started(wave: int) -> void:
	_report_progress(wave, data.waves_to_survive)


func _on_wave_cleared(wave: int) -> void:
	if wave >= data.waves_to_survive:
		_spawner.stop()
		_complete()
