class_name GatherNode
extends Area3D
## A harvestable resource node. A player standing in it and holding interact fills
## the progress bar; letting go drains it. When full, it reports the materials and vanishes.

@export var gather_material: MaterialData
@export var yield_amount: int = 2
@export var harvest_time: float = 1.2 ## Seconds of holding interact.

var _progress: float = 0.0
var _harvested: bool = false

@onready var visual: Node3D = $Visual
@onready var prompt: Label3D = $Prompt
@onready var bar: MeshInstance3D = $ProgressBar


func _ready() -> void:
	prompt.text = tr("UI_GATHER_PROMPT") % InputHints.key_for("interact")
	if not _can_gather():
		prompt.text = tr("UI_REQUIRES") % Progression.requirement_text(
			Progression.GATHERING, gather_material.gather_skill, gather_material.tier)
	prompt.visible = false
	bar.visible = false
	if gather_material:
		_tint(gather_material.color)


func _physics_process(delta: float) -> void:
	if _harvested:
		return
	var gatherer: Player = _find_gathering_player() if _can_gather() else null
	if gatherer:
		_progress += delta
	else:
		_progress = maxf(_progress - delta * 2.0, 0.0)
	prompt.visible = gatherer == null and _has_player_in_range()
	bar.visible = _progress > 0.0
	bar.scale.x = maxf(_progress / harvest_time, 0.01)
	if _progress >= harvest_time:
		_harvest()


## Higher-tier nodes need a higher gathering level (Albion-style).
func _can_gather() -> bool:
	if gather_material == null or gather_material.gather_skill == &"":
		return true
	return SaveManager.meets_tier(Progression.GATHERING, gather_material.gather_skill, gather_material.tier)


func _find_gathering_player() -> Player:
	for body: Node3D in get_overlapping_bodies():
		var player: Player = body as Player
		if player and player.is_alive() and player.is_interacting():
			return player
	return null


func _has_player_in_range() -> bool:
	for body: Node3D in get_overlapping_bodies():
		var player: Player = body as Player
		if player and player.is_alive():
			return true
	return false


func _harvest() -> void:
	_harvested = true
	prompt.visible = false
	bar.visible = false
	EventBus.material_obtained.emit(gather_material, yield_amount)
	EventBus.resource_harvested.emit(gather_material, yield_amount)
	var tween: Tween = create_tween()
	tween.tween_property(visual, "scale", Vector3(1.3, 0.05, 1.3), 0.2)
	tween.tween_callback(queue_free)


func _tint(color: Color) -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	for child: Node in visual.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = mat
