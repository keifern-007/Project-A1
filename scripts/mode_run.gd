class_name ModeRun
extends RefCounted
## A run made of several steps (Endless Boss, Classic). Each step is one normal objective on its own
## map, played in a fresh load of the run scene. This holds what carries over between steps:
## HP, Run Level, kills, time and rewards (potions carry by themselves: using one saves at once).
## Classic also keeps this in the save at the start of each step, so the run can be resumed.

const ENDLESS_BOSS_HEAL: float = 0.3 ## Share of max HP back after each boss in Endless Boss.

var mode: ObjectiveData
var return_map: MapData ## What the Mission Board had selected, restored when the run ends.
var character_id: String = ""
var challenge: ChallengeData
var run_seed: int = 0
var step: int = 0
var hp: int = -1 ## -1 = full, for the first step.
var level: int = 1
var xp: int = 0
var kills: int = 0
var run_time: float = 0.0
var rewards: Dictionary = {}

var _bosses: Array[ObjectiveData] = []


static func create(mode_data: ObjectiveData, board_map: MapData) -> ModeRun:
	var run: ModeRun = ModeRun.new()
	run.mode = mode_data
	run.return_map = board_map
	run.character_id = str(SaveManager.get_character().id)
	run.challenge = GameState.challenge
	run.run_seed = int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec()
	run._pick_bosses()
	return run


## The saved Classic run, or null if there is none (or it no longer makes sense).
static func load_saved(mode_data: ObjectiveData, board_map: MapData) -> ModeRun:
	var saved: Dictionary = SaveManager.profile["classic_run"]
	if saved.is_empty():
		return null
	var run: ModeRun = ModeRun.create(mode_data, board_map)
	run.character_id = str(saved.get("character", run.character_id))
	var challenge_path: String = str(saved.get("challenge", ""))
	run.challenge = load(challenge_path) if ResourceLoader.exists(challenge_path) else null
	run.run_seed = int(saved.get("seed", run.run_seed))
	run.step = int(saved.get("step", 0))
	run.hp = int(saved.get("hp", -1))
	run.level = int(saved.get("level", 1))
	run.xp = int(saved.get("xp", 0))
	run.kills = int(saved.get("kills", 0))
	run.run_time = float(saved.get("run_time", 0.0))
	run.rewards = _clean_rewards(saved.get("rewards", {}))
	return run if run.step < run._total_steps() else null


func _pick_bosses() -> void:
	for boss: ObjectiveData in mode.boss_sequence:
		var locked: bool = maxi(boss.required_rank, boss.only_on_map.required_rank) > SaveManager.get_rank()
		if mode.type == ObjectiveData.Type.CLASSIC or not locked: # Endless Boss: only bosses you've unlocked.
			_bosses.append(boss)


func _cycle() -> int:
	return mode.stages_per_boss + 1


func _in_cycle() -> int:
	return step % _cycle()


func _total_steps() -> int:
	return _cycle() * _bosses.size()


func is_boss_step() -> bool:
	return _in_cycle() == mode.stages_per_boss


func _current_boss() -> ObjectiveData:
	return _bosses[(step / _cycle()) % _bosses.size()]


func step_objective() -> ObjectiveData:
	return _current_boss() if is_boss_step() else mode.stage_objective


## Waves before this stage, so later stages are harder and keep unlocking tougher enemies.
func start_wave() -> int:
	return 0 if is_boss_step() else _in_cycle() * mode.stage_objective.waves_to_survive


func has_next_step() -> bool:
	return mode.is_endless() or step + 1 < _total_steps()


func boss_health_multiplier() -> float:
	return 1.0 + mode.boss_health_growth * step


func bosses_defeated() -> int:
	return step / _cycle()


## "Classic 2/3: Stage 1/4" for the HUD, the banners and the Mission Board.
func progress_text() -> String:
	if mode.is_endless():
		return TranslationServer.translate("MODE_ENDLESS_BOSS") % (step + 1)
	var chapter: int = bosses_defeated() + 1
	if is_boss_step():
		return TranslationServer.translate("MODE_CLASSIC_BOSS") % [chapter, _bosses.size()]
	return TranslationServer.translate("MODE_CLASSIC_STAGE") % [chapter, _bosses.size(), _in_cycle() + 1, mode.stages_per_boss]


## Called as the run scene loads, before anything reads the map or objective.
func enter_step() -> void:
	GameState.map = _current_boss().only_on_map
	GameState.objective = step_objective()
	GameState.challenge = challenge
	if mode.type == ObjectiveData.Type.CLASSIC:
		SaveManager.set_classic_run(_to_save())


## Called after GameState.start_run(): the fresh run continues where the last step stopped.
func restore(player: Player) -> void:
	GameState.kills = kills
	GameState.run_time = run_time
	GameState.run_rewards = rewards.duplicate(true)
	if player == null:
		return
	player.level.restore(level, xp)
	if hp >= 0:
		player.health.set_current(hp)


## Called when a step is won, on the way to the next one.
func advance(player: Player) -> void:
	hp = maxi(player.health.current, 1)
	if mode.is_endless():
		hp = mini(hp + roundi(player.health.max_health * ENDLESS_BOSS_HEAL), player.health.max_health)
	level = player.level.level
	xp = player.level.xp
	kills = GameState.kills
	run_time = GameState.run_time
	rewards = GameState.run_rewards.duplicate(true)
	step += 1


## The Mission Board goes back to showing this mode.
func leave() -> void:
	GameState.map = return_map
	GameState.objective = mode
	GameState.mode_run = null


func _to_save() -> Dictionary:
	return {
		"character": character_id,
		"challenge": challenge.resource_path if challenge else "",
		"seed": run_seed,
		"step": step,
		"hp": hp,
		"level": level,
		"xp": xp,
		"kills": kills,
		"run_time": run_time,
		"rewards": rewards,
	}


## JSON brings numbers back as floats and ids as Strings.
static func _clean_rewards(saved: Dictionary) -> Dictionary:
	var cleaned: Dictionary = {}
	var materials: Dictionary = {}
	for id: Variant in saved.get("materials", {}):
		materials[StringName(str(id))] = int(saved["materials"][id])
	if not materials.is_empty():
		cleaned["materials"] = materials
	var tracks: Dictionary = {}
	for track: Variant in saved.get("xp", {}):
		tracks[str(track)] = int(saved["xp"][track])
	if not tracks.is_empty():
		cleaned["xp"] = tracks
	return cleaned
