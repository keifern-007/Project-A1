extends Control
## The run: loads the chosen map into the RetroScreen, starts the objective, ends the run
## (victory or wipe), saves rewards and shows the results.

const CAMP_SCENE: String = "res://scenes/main/hub.tscn"
const GAME_OVER_DELAY: float = 1.2 ## Seconds to watch the death before the screen appears.

## Fallbacks for running this scene directly (F6) without going through mission select.
@export var default_map: MapData = preload("res://resources/maps/greybox.tres")
@export var default_objective: ObjectiveData = preload("res://resources/objectives/horde_standard.tres")

@onready var retro_screen: RetroScreen = $RetroScreen
@onready var hud: HUD = $UI/HUD
@onready var game_over: GameOverScreen = $UI/GameOver

var _player: Player


func _ready() -> void:
	add_child(LootDropper.new())
	_load_map()
	# Every load of this scene is a fresh run (Restart reloads it).
	GameState.start_run()
	_player = get_tree().get_first_node_in_group("players")
	if _player:
		hud.bind_player(_player)
	EventBus.player_died.connect(_on_player_died)
	game_over.restart_requested.connect(_restart)
	game_over.quit_requested.connect(get_tree().quit)
	game_over.camp_requested.connect(_go_to_camp)
	_start_objective()


func _load_map() -> void:
	if GameState.map == null:
		GameState.map = default_map
	var map_data: MapData = GameState.map as MapData
	retro_screen.add_world(map_data.scene.instantiate())


func _start_objective() -> void:
	if GameState.objective == null:
		GameState.objective = default_objective
	var objective: Objective = Objective.create(GameState.objective)
	if objective:
		objective.completed.connect(_end_run.bind(true))
		add_child(objective)


# Co-op ready: the run only ends when nobody is left standing.
func _on_player_died(_player: Node) -> void:
	if not GameState.run_active:
		return
	for node: Node in get_tree().get_nodes_in_group("players"):
		var player: Player = node as Player
		if player and player.is_alive():
			return
	_end_run(false)


func _end_run(victory: bool) -> void:
	GameState.end_run(victory)
	if victory:
		# Deferred so it runs after the killing blow's loot is spawned (also deferred).
		_vacuum_loot.call_deferred()
	await get_tree().create_timer(GAME_OVER_DELAY).timeout
	GameFeel.cancel_hit_stop()
	get_tree().paused = true
	hud.hide() # The results screen says it all; avoids a frozen banner or skill box underneath.
	# Saved after the loot vacuum, so everything collected counts.
	var bonus: float = GameState.apply_challenge_bonus(victory)
	var level_ups: Array[Dictionary] = SaveManager.commit_run(GameState.run_rewards, victory)
	var level: int = _player.level.level if _player else 1
	game_over.show_results(victory, GameState.run_time, GameState.kills, level, _collect_rewards(),
		_xp_lines(level_ups, bonus))


func _restart() -> void:
	GameFeel.cancel_hit_stop()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _go_to_camp() -> void:
	GameFeel.cancel_hit_stop()
	get_tree().paused = false
	get_tree().change_scene_to_file(CAMP_SCENE)


func _collect_rewards() -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	var materials: Dictionary = GameState.run_rewards.get("materials", {})
	for id: StringName in materials:
		rewards.append({
			"material": GameState.get_material_data(id),
			"amount": materials[id],
			"owned": SaveManager.get_material_count(str(id)),
		})
	return rewards


# Loot vacuum: nothing you earned is left lying on the ground (e.g. the boss's XP gem).
func _vacuum_loot() -> void:
	if _player == null or not _player.is_alive():
		return
	for pickup: Node in get_tree().get_nodes_in_group("pickups"):
		(pickup as Pickup).attract(_player)


## "Dagger Mastery  +45 XP", ... (all of it Rank XP), then "Rank 3!  +3 skill points".
func _xp_lines(level_ups: Array[Dictionary], bonus: float) -> Array[String]:
	var lines: Array[String] = []
	if bonus > 1.0:
		lines.append(tr("UI_CHALLENGE_BONUS") % [tr(GameState.challenge.name_key), bonus])
	var xp: Dictionary = GameState.run_rewards.get("xp", {})
	for track: String in xp:
		lines.append(tr("UI_XP_ROW") % [Progression.display_name(track), xp[track]])
	for level_up: Dictionary in level_ups:
		lines.append(tr("UI_RANK_UP") % [level_up["level"], level_up["points"]])
	return lines
