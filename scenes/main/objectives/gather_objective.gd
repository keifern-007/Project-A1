class_name GatherObjective
extends Objective
## Collect N of one material from gather nodes while endless waves harass you.
## Nodes spawn at the map's Marker3Ds in group "gather_points", only for this objective.

var _gathered: int = 0
var _spawner: WaveSpawner


func _ready() -> void:
	_spawn_gather_nodes()
	EventBus.material_obtained.connect(_on_material_obtained)
	_report_progress(0, data.gather_amount)
	_spawner = _setup_spawner(0) # 0 = endless harassment until the objective is done.


func _spawn_gather_nodes() -> void:
	var points: Array[Node] = get_tree().get_nodes_in_group("gather_points")
	var total_yield: int = 0
	for point: Node in points:
		var node: GatherNode = data.gather_node_scene.instantiate()
		node.gather_material = data.gather_material
		point.add_child(node)
		total_yield += node.yield_amount
	if total_yield < data.gather_amount:
		push_warning("GatherObjective: map only has %d %s, objective needs %d." \
			% [total_yield, data.gather_material.id, data.gather_amount])


func _on_material_obtained(material: MaterialData, amount: int) -> void:
	if material != data.gather_material or _gathered >= data.gather_amount:
		return
	_gathered = mini(_gathered + amount, data.gather_amount)
	_report_progress(_gathered, data.gather_amount)
	if _gathered >= data.gather_amount:
		if _spawner:
			_spawner.stop()
		_complete()
