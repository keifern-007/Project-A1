extends Node
## Data for the run currently being played. Reset at the start of every run.
## Character/map/objective become typed Resources (CharacterData, MapData, ObjectiveData) in later phases.

var character: Resource = null
var map: Resource = null
var objective: Resource = null
## Difficulty picked on the Mission Board. null (e.g. F6 on the run scene) = Normal.
var challenge: ChallengeData = null

var run_seed: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var run_active: bool = false
var run_time: float = 0.0
var kills: int = 0
var wave: int = 0
var run_rewards: Dictionary = {}


func _ready() -> void:
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.material_obtained.connect(_on_material_obtained)
	EventBus.resource_harvested.connect(_on_resource_harvested)


## Pass a seed to replay/sync a run; 0 picks a fresh one.
func start_run(seed_value: int = 0) -> void:
	if seed_value == 0:
		seed_value = int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec()
	run_seed = seed_value
	rng.seed = run_seed
	run_time = 0.0
	kills = 0
	wave = 0
	run_rewards = {}
	run_active = true
	EventBus.run_started.emit()


func _process(delta: float) -> void:
	if run_active:
		run_time += delta


## This run's biome (null = enemies stay their base type).
func biome() -> BiomeData:
	return (map as MapData).biome if map else null


func enemy_health_multiplier() -> float:
	return challenge.enemy_health_multiplier if challenge else 1.0


func damage_taken_multiplier() -> float:
	return challenge.damage_taken_multiplier if challenge else 1.0


## Won a challenge? Multiply this run's materials and XP (rounded up). Call once, after
## all loot is collected and before saving. Returns the multiplier applied (1.0 = none).
func apply_challenge_bonus(victory: bool) -> float:
	if not victory or challenge == null or challenge.reward_multiplier <= 1.0:
		return 1.0
	for key: String in ["materials", "xp"]:
		var rewards: Dictionary = run_rewards.get(key, {})
		for id: Variant in rewards:
			rewards[id] = ceili(rewards[id] * challenge.reward_multiplier)
	return challenge.reward_multiplier


func end_run(victory: bool) -> void:
	run_active = false
	EventBus.run_ended.emit(victory)


func _on_enemy_killed(enemy: Node) -> void:
	kills += 1
	var data: EnemyData = enemy.get("data") as EnemyData
	if data == null or data.xp_reward <= 0:
		return
	# Each kill counts once toward Rank, listed under the main hand (armor earns nothing extra).
	var weapon: ItemData = SaveManager.get_equipped(ItemData.Slot.MAIN_HAND)
	var category: StringName = weapon.category if weapon else Progression.UNARMED_CATEGORY
	_add_run_xp(Progression.track_key(Progression.MASTERY, category), data.xp_reward)


func _on_wave_started(wave_number: int) -> void:
	wave = wave_number


## run_rewards["materials"] = { material id: amount }. Phase 3 saves these to the profile.
func _on_material_obtained(material: Resource, amount: int) -> void:
	var materials: Dictionary = run_rewards.get_or_add("materials", {})
	var id: StringName = (material as MaterialData).id
	materials[id] = materials.get(id, 0) + amount


func get_material_data(id: StringName) -> MaterialData:
	return MaterialRegistry.get_by_id(str(id))


func _on_resource_harvested(material: Resource, amount: int) -> void:
	var skill: StringName = (material as MaterialData).gather_skill
	if skill != &"":
		_add_run_xp(Progression.track_key(Progression.GATHERING, skill), amount * Progression.GATHER_XP_PER_ITEM)


## run_rewards["xp"] = { track key: xp }: where this run's Rank XP came from. Saved (and shown) when the run ends.
func _add_run_xp(track: String, amount: int) -> void:
	var xp: Dictionary = run_rewards.get_or_add("xp", {})
	xp[track] = xp.get(track, 0) + amount
