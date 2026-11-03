class_name MapRegion
extends Area3D
## A site on a big map with its own goal: defeat what lives there, gather its plants, open its cache
## or rest at its shrine. Nothing happens until a hero first walks in: then its enemies come, from
## its own WaveSpawner (if it has one). Sites are small scenes (scenes/maps/site_*.tscn) that a
## SiteScatter places on the map each run.
## Scene needs: a CollisionShape3D (the site's area); a WaveSpawner child named "WaveSpawner"
## (autostart off, Marker3D spawn points) if enemy_count > 0; for GATHER, Marker3D children of a
## "GatherPoints" node; for CACHE and SHRINE, an Interactable child named "Interact".
## A sign floating above it names it and its goal (text, not color), within sign_range metres.

signal progress_changed
signal completed

enum Goal { DEFEAT, GATHER, CACHE, SHRINE }

const SIGN_PIXEL_SIZE: float = 0.0014 ## The sign keeps this size on screen at any distance.
const GOAL_KEYS: Array[String] = ["REGION_GOAL_DEFEAT", "REGION_GOAL_GATHER", "REGION_GOAL_CACHE", "REGION_GOAL_SHRINE"]

@export var name_key: String = ""
@export var goal: Goal = Goal.DEFEAT
## Like a wave number: higher brings tougher enemy types (SpawnEntry.from_wave) and more HP.
## A SiteScatter sets it from the distance to base camp, plus level_bonus.
@export var level: int = 1
@export var level_bonus: int = 0 ## A tougher kind of site (a watchtower) adds this.
@export var enemy_count: int = 6 ## DEFEAT: all of them. Other goals: guards that come when you arrive.
## Set = these enemies instead of the map's pool (a puffcap ring, a tusker wallow).
@export var enemy_pool_override: Array[SpawnEntry] = []
@export var gather_material: MaterialData
@export var gather_amount: int = 6
@export var gather_node_scene: PackedScene
@export var cache_rewards: Array[MaterialCost] = [] ## CACHE: what opening it gives.
@export var sign_height: float = 6.0
@export var sign_range: float = 70.0

var progress: int = 0
var done: bool = false
var player_inside: bool = false

var _woken: bool = false
var _enemy_pool: Array[SpawnEntry] = []
var _own_enemies: Dictionary = {} # Enemy -> true, so other sites' kills don't count here.
var _sign: Label3D

@onready var spawner: WaveSpawner = get_node_or_null("WaveSpawner")


func _ready() -> void:
	add_to_group("map_regions")
	collision_layer = 0
	collision_mask = 2 # Players.
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if spawner:
		spawner.enemy_spawned.connect(func(enemy: Node3D) -> void: _own_enemies[enemy] = true)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	var interact: Interactable = get_node_or_null("Interact")
	if interact:
		interact.interacted.connect(_on_interacted)
	_make_sign()
	if goal == Goal.GATHER:
		_place_gather_nodes()


## Called by the objective: which enemies this map uses (unless the site has its own).
func setup(enemy_pool: Array[SpawnEntry]) -> void:
	_enemy_pool = enemy_pool if enemy_pool_override.is_empty() else enemy_pool_override


func goal_amount() -> int:
	match goal:
		Goal.DEFEAT:
			return enemy_count
		Goal.GATHER:
			return gather_amount
	return 1


## "Goblin Camp: Defeat them all" for the HUD.
func hud_text() -> String:
	return tr("REGION_HUD") % [tr(name_key), tr(GOAL_KEYS[goal])]


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null or not player.controlled:
		return
	player_inside = true
	_sign.visible = false # Right overhead it would cover the HUD, which shows the same goal.
	if not _woken and not done:
		_wake()
	progress_changed.emit()


func _on_body_exited(body: Node3D) -> void:
	var player: Player = body as Player
	if player and player.controlled:
		player_inside = false
		_sign.visible = true
		progress_changed.emit()


func _wake() -> void:
	_woken = true
	if spawner == null or enemy_count <= 0 or _enemy_pool.is_empty():
		return
	spawner.enemy_pool = _enemy_pool
	spawner.first_wave_size = enemy_count
	spawner.wave_size_growth = 0
	spawner.wave = level + level_bonus - 1 # One wave, numbered by the site's level.
	spawner.max_waves = level + level_bonus
	spawner.wave_cleared.connect(func(_wave: int) -> void:
		if goal == Goal.DEFEAT:
			_finish())
	spawner.start()


func _on_enemy_killed(enemy: Node) -> void:
	if not _own_enemies.has(enemy) or done:
		return
	_own_enemies.erase(enemy)
	if goal == Goal.DEFEAT:
		progress = mini(progress + 1, enemy_count)
		_refresh()


## The cache opens (its loot), or the stones heal the hero completely.
func _on_interacted(player: Player) -> void:
	if done:
		return
	if goal == Goal.CACHE:
		for reward: MaterialCost in cache_rewards:
			EventBus.material_obtained.emit(reward.material, reward.amount)
	elif goal == Goal.SHRINE:
		player.health.heal(player.health.max_health)
	(get_node("Interact") as Interactable).enabled = false
	_finish()


func _place_gather_nodes() -> void:
	for point: Node in get_node("GatherPoints").get_children():
		var node: GatherNode = gather_node_scene.instantiate()
		node.gather_material = gather_material
		point.add_child(node)
		node.harvested.connect(_on_harvested)


func _on_harvested(amount: int) -> void:
	if done:
		return
	progress = mini(progress + amount, gather_amount)
	_refresh()
	if progress >= gather_amount:
		_finish()


func _finish() -> void:
	if done:
		return
	done = true
	progress = goal_amount()
	_refresh()
	completed.emit()


func _refresh() -> void:
	if done:
		_sign.text = tr("REGION_SIGN_DONE") % tr(name_key)
	elif goal == Goal.CACHE or goal == Goal.SHRINE:
		_sign.text = "%s\n%s" % [tr(name_key), tr(GOAL_KEYS[goal])]
	else:
		_sign.text = tr("REGION_SIGN") % [tr(name_key), tr(GOAL_KEYS[goal]), progress, goal_amount()]
	progress_changed.emit()


func _make_sign() -> void:
	_sign = Label3D.new()
	_sign.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.no_depth_test = true
	_sign.fixed_size = true
	_sign.pixel_size = SIGN_PIXEL_SIZE
	_sign.font_size = 40
	_sign.outline_size = 12
	_sign.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sign.position = Vector3(0.0, sign_height, 0.0)
	_sign.visibility_range_end = sign_range # Farther away, the compass guides instead of a crowd of signs.
	add_child(_sign)
	_refresh()
