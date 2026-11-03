class_name EndlessObjective
extends Objective
## Endless Survival: waves never stop growing and the run only ends when you fall, so it never completes.


func _ready() -> void:
	_report_progress(0, 0, WAVE_KEY)
	var spawner: WaveSpawner = _setup_spawner(0)
	if spawner:
		spawner.wave_started.connect(func(wave: int) -> void: _report_progress(wave, 0, WAVE_KEY))
