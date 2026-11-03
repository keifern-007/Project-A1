class_name MapRegion
extends Area3D
## One region of a big map, with its own goal (defeat its enemies, or gather its plants).
## Nothing happens until a hero first walks in: then its enemies come, from its own WaveSpawner.
## Scene needs: a CollisionShape3D (the region's area), a WaveSpawner child named "WaveSpawner"
## (autostart off, with Marker3D spawn points) and, for GATHER, Marker3D children of a "GatherPoints" node.
## A sign floating high above it names it and its goal, so it can be found from anywhere (text, not color).

signal progress_changed
signal completed

enum Goal { DEFEAT, GATHER }

const SIGN_PIXEL_SIZE: float = 0.0014 ## The sign keeps this size on screen at any distance.
const SIGN_RANGE: float = 70.0 ## Metres from the camera within which the sign shows.

@export var name_key: String = ""
@export var goal: Goal = Goal.DEFEAT
## Like a wave number: higher brings tougher enemy types (SpawnEntry.from_wave) and more HP.
@export var level: int = 1
@export var enemy_count: int = 6 ## DEFEAT: all of them. GATHER: they harass you while you gather.
@export var gather_material: MaterialData
@export var gather_amount: int = 6
@export var gather_node_scene: PackedScene
@export var sign_height: float = 6.0

var progress: int = 0
var done: bool = false
var player_inside: bool = false

var _woken: bool = false
var _enemy_pool: Array[SpawnEntry] = []
var _own_enemies: Dictionary = {} # Enemy -> true, so other regions' kills don't count here.
var _sign: Label3D

@onready var spawner: WaveSpawner = $WaveSpawner


func _ready() -> void:
	add_to_group("map_regions")
	collision_layer = 0
	collision_mask = 2 # Players.
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	spawner.enemy_spawned.connect(func(enemy: Node3D) -> void: _own_enemies[enemy] = true)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	_make_sign()
	if goal == Goal.GATHER:
		_place_gather_nodes()


## Called by the objective: which enemies this map uses.
func setup(enemy_pool: Array[SpawnEntry]) -> void:
	_enemy_pool = enemy_pool


func goal_amount() -> int:
	return enemy_count if goal == Goal.DEFEAT else gather_amount


## "Old Clearing: Defeat the goblins" for the HUD.
func hud_text() -> String:
	return tr("REGION_HUD") % [tr(name_key), tr(_goal_key())]


func _goal_key() -> String:
	return "REGION_GOAL_DEFEAT" if goal == Goal.DEFEAT else "REGION_GOAL_GATHER"


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
	spawner.enemy_pool = _enemy_pool
	spawner.first_wave_size = enemy_count
	spawner.wave_size_growth = 0
	spawner.wave = level - 1 # One wave, numbered `level`.
	spawner.max_waves = level
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
	else:
		_sign.text = tr("REGION_SIGN") % [tr(name_key), tr(_goal_key()), progress, goal_amount()]
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
	_sign.visibility_range_end = SIGN_RANGE # Farther away, the HUD's pointer guides instead of a crowd of signs.
	add_child(_sign)
	_refresh()
