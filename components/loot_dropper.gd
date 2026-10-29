class_name LootDropper
extends Node
## Rolls loot when any enemy dies: an XP gem plus its EnemyData drop table.
## All loot decisions happen here (seeded RNG), so in co-op only the host runs it.

const PICKUP_SCENE: PackedScene = preload("res://scenes/maps/pickup.tscn")
const SCATTER: float = 0.8


func _ready() -> void:
	EventBus.enemy_killed.connect(_on_enemy_killed)


func _on_enemy_killed(enemy: Node) -> void:
	var data: EnemyData = enemy.get("data") as EnemyData
	var body: Node3D = enemy as Node3D
	if data == null or body == null:
		return
	var rng: RandomNumberGenerator = GameState.rng
	if data.xp_reward > 0:
		_spawn(body, func(p: Pickup) -> void: p.xp = data.xp_reward)
	for entry: DropEntry in data.drops:
		if rng.randf() >= entry.chance:
			continue
		var amount: int = rng.randi_range(entry.min_amount, maxi(entry.min_amount, entry.max_amount))
		_spawn(body, func(p: Pickup) -> void:
			p.drop_material = entry.material
			p.booster = entry.booster
			p.amount = amount)


func _spawn(enemy: Node3D, fill: Callable) -> void:
	var pickup: Pickup = PICKUP_SCENE.instantiate()
	fill.call(pickup)
	var rng: RandomNumberGenerator = GameState.rng
	var offset: Vector3 = Vector3(rng.randf_range(-SCATTER, SCATTER), 0.0, rng.randf_range(-SCATTER, SCATTER))
	var map: Node3D = enemy.get_parent() as Node3D
	pickup.position = map.to_local(enemy.global_position + offset)
	# Deferred: this often runs inside a physics callback (the killing blow).
	map.add_child.call_deferred(pickup)
