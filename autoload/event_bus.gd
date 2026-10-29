extends Node
## Global signals only. Anything can emit or connect here without knowing who else is listening.
## Keep this file to signal declarations — no logic.

@warning_ignore_start("unused_signal")

signal run_started
signal run_ended(victory: bool)
signal player_died(player: Node)
signal enemy_killed(enemy: Node)
signal wave_started(wave: int)
signal material_obtained(material: Resource, amount: int)
signal resource_harvested(material: Resource, amount: int) ## From gather nodes only.
signal boss_spawned(boss: Node)
signal boss_defeated(boss: Node)
signal objective_progress(name_key: String, current: int, target: int)
signal settings_changed
signal screen_shake_requested(trauma: float) ## Use GameFeel.shake(), not this directly.

@warning_ignore_restore("unused_signal")
