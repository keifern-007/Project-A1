extends Control
## The run: loads the chosen map into the RetroScreen, starts the objective, ends the run
## (victory or wipe), saves rewards and shows the results.

const CAMP_SCENE: String = "res://scenes/main/hub.tscn"
const GAME_OVER_DELAY: float = 1.2 ## Seconds to watch the death before the screen appears.
const TUTORIAL_BOX: PackedScene = preload("res://scenes/ui/tutorial_box.tscn")

## Fallbacks for running this scene directly (F6) without going through mission select.
@export var default_map: MapData = preload("res://resources/maps/greybox.tres")
@export var default_objective: ObjectiveData = preload("res://resources/objectives/horde_standard.tres")

@onready var retro_screen: RetroScreen = $RetroScreen
@onready var hud: HUD = $UI/HUD
@onready var game_over: GameOverScreen = $UI/GameOver
@onready var pause_menu: PauseMenu = $UI/PauseMenu

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
	pause_menu.leave_requested.connect(_leave_mission)
	_start_objective()


func _load_map() -> void:
	if GameState.map == null:
		GameState.map = default_map
	var map_data: MapData = GameState.map as MapData
	var world: Node = map_data.scene.instantiate()
	retro_screen.add_world(world)
	if GameState.objective == null:
		GameState.objective = default_objective
	var objective_data: ObjectiveData = GameState.objective as ObjectiveData
	if objective_data.mood:
		add_child(MissionMood.create(objective_data.mood, world, map_data.biome))


func _start_objective() -> void:
	if GameState.objective == null:
		GameState.objective = default_objective
	var objective: Objective = Objective.create(GameState.objective)
	if objective:
		objective.completed.connect(_end_run.bind(true))
		if objective is TutorialObjective:
			_add_tutorial_box(objective)
		add_child(objective)


## The tutorial teaches through its own box. Connected before the objective starts, so its first lesson shows.
func _add_tutorial_box(tutorial: TutorialObjective) -> void:
	var box: TutorialBox = TUTORIAL_BOX.instantiate()
	$UI.add_child(box)
	$UI.move_child(box, hud.get_index() + 1) # Below the pause menu.
	tutorial.step_shown.connect(box.show_step)
	tutorial.guide_requested.connect(box.show_guide)
	box.guide_closed.connect(tutorial.finish)


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
	# Only the first result counts: a Burn tick can finish the boss during the death delay.
	if not GameState.run_active:
		return
	GameState.end_run(victory)
	if _is_tutorial():
		_leave_tutorial()
		return
	if victory:
		# Deferred so it runs after the killing blow's loot is spawned (also deferred).
		_vacuum_loot.call_deferred()
	await get_tree().create_timer(GAME_OVER_DELAY).timeout
	_show_results(victory)


## Pause menu: the run ends now, under the same rules as a defeat (the game is already paused).
func _leave_mission() -> void:
	GameState.end_run(false)
	if _is_tutorial():
		_leave_tutorial()
		return
	_show_results(false, true)


func _is_tutorial() -> bool:
	return (GameState.objective as ObjectiveData).type == ObjectiveData.Type.TUTORIAL


## Practice only: no results and nothing saved, straight back to camp. The Mission Board
## starts from its defaults instead of looking for the tutorial among its missions.
func _leave_tutorial() -> void:
	GameState.map = null
	GameState.objective = null
	_go_to_camp()


func _show_results(victory: bool, left_mission: bool = false) -> void:
	GameFeel.cancel_hit_stop()
	get_tree().paused = true
	hud.hide() # The results screen says it all; avoids a frozen banner or skill box underneath.
	# Saved after the loot vacuum, so everything collected counts.
	var bonus: float = GameState.apply_challenge_bonus(victory)
	var level_ups: Array[Dictionary] = SaveManager.commit_run(GameState.run_rewards, victory)
	var level: int = _player.level.level if _player else 1
	game_over.show_results(victory, GameState.run_time, GameState.kills, level, _collect_rewards(),
		_xp_lines(level_ups, bonus), left_mission)


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
