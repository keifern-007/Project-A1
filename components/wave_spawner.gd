class_name WaveSpawner
extends Node3D
## Spawns enemies in waves at its Marker3D children. Each wave is bigger than the last.
## The next wave starts after a short break once the current one is cleared,
## or anyway after max_wave_time so the pressure never stops.
## Phase 2's Horde objective will drive this (wave count, difficulty) from ObjectiveData.

signal wave_started(wave: int)
signal wave_cleared(wave: int)

@export var enemy_scenes: Array[PackedScene] = []
@export var autostart: bool = true

@export_group("Waves")
@export var first_wave_size: int = 3
@export var wave_size_growth: int = 2 ## Extra enemies per wave.
@export var spawn_interval: float = 0.5 ## Seconds between individual spawns.
@export var first_wave_delay: float = 1.0
@export var break_time: float = 3.0 ## Pause between waves.
@export var max_wave_time: float = 25.0
@export var max_waves: int = 0 ## 0 = endless. Otherwise stops after this wave is cleared.
@export var health_growth_per_wave: float = 0.0 ## 0.15 = +15% enemy HP per wave.

@export_group("Limits")
@export var max_alive: int = 40 ## Performance cap.
@export var min_player_distance: float = 6.0 ## Don't spawn on top of a player.

var wave: int = 0
var alive: int = 0

var _running: bool = false
var _to_spawn: int = 0
var _spawn_timer: float = 0.0
var _wave_timer: float = 0.0
var _break_timer: float = 0.0
var _spawn_points: Array[Marker3D] = []
var _spawned: Array[Node3D] = []


func _ready() -> void:
	for child: Node in get_children():
		if child is Marker3D:
			_spawn_points.append(child)
	add_to_group("wave_spawners")
	if autostart:
		start()


func start() -> void:
	_running = true
	_break_timer = first_wave_delay


func stop() -> void:
	_running = false


func _physics_process(delta: float) -> void:
	if not _running or enemy_scenes.is_empty() or _spawn_points.is_empty():
		return
	if _break_timer > 0.0:
		_break_timer -= delta
		if _break_timer <= 0.0:
			_start_wave()
		return

	_wave_timer += delta
	if _to_spawn > 0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0 and alive < max_alive:
			_spawn_enemy()
			_to_spawn -= 1
			_spawn_timer = spawn_interval
	# The final wave must actually be cleared; earlier waves can time out.
	elif alive == 0 or (_wave_timer >= max_wave_time and not _is_final_wave()):
		if alive == 0:
			wave_cleared.emit(wave)
		if _is_final_wave():
			stop()
			return
		_break_timer = break_time


func _start_wave() -> void:
	wave += 1
	_to_spawn = first_wave_size + wave_size_growth * (wave - 1)
	_wave_timer = 0.0
	_spawn_timer = 0.0
	wave_started.emit(wave)
	EventBus.wave_started.emit(wave)


func _spawn_enemy() -> void:
	var rng: RandomNumberGenerator = GameState.rng
	var scene: PackedScene = enemy_scenes[rng.randi_range(0, enemy_scenes.size() - 1)]
	var enemy: Node3D = scene.instantiate()
	# Spawned enemies know where you are — no waiting in IDLE.
	if "hunt_from_start" in enemy:
		enemy.set("hunt_from_start", true)
	if "health_multiplier" in enemy:
		enemy.set("health_multiplier", 1.0 + health_growth_per_wave * (wave - 1))
	enemy.tree_exited.connect(_on_enemy_removed.bind(enemy))
	get_parent().add_child(enemy)
	var jitter: Vector3 = Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
	enemy.global_position = _pick_spawn_point().global_position + jitter
	alive += 1
	_spawned.append(enemy)


## A random spawn point that isn't too close to any player (or any point, if all are close).
func _pick_spawn_point() -> Marker3D:
	var safe: Array[Marker3D] = []
	for point: Marker3D in _spawn_points:
		if _is_far_from_players(point.global_position):
			safe.append(point)
	var pool: Array[Marker3D] = safe if not safe.is_empty() else _spawn_points
	return pool[GameState.rng.randi_range(0, pool.size() - 1)]


func _is_far_from_players(pos: Vector3) -> bool:
	for player: Node in get_tree().get_nodes_in_group("players"):
		if player is Node3D and (player as Node3D).global_position.distance_to(pos) < min_player_distance:
			return false
	return true


func _is_final_wave() -> bool:
	return max_waves > 0 and wave >= max_waves


## Clears every enemy this spawner made, without kill credit.
func despawn_all() -> void:
	for enemy: Node3D in _spawned.duplicate():
		if enemy.has_method("despawn"):
			enemy.call("despawn")
		else:
			enemy.queue_free()


func _on_enemy_removed(enemy: Node3D) -> void:
	alive -= 1
	_spawned.erase(enemy)
