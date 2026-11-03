class_name ExpeditionObjective
extends Objective
## Big maps: each MapRegion (group "map_regions") has its own goal, and finishing them all wins.
## Unfinished regions are quest markers on the HUD compass. The map's cart (an Interactable with
## action &"cart") ends the mission early instead: you keep what you collected, but it isn't a win.
## Riding home takes a second press, so it can't happen by accident.

signal cart_taken

const REGIONS_KEY: String = "OBJ_REGIONS"
const CART_CONFIRM_TIME: float = 3.0
const REPORT_REFRESH: float = 0.25

var _regions: Array[MapRegion] = []
var _cart: Interactable
var _cart_armed_left: float = 0.0
var _finished: bool = false
var _report_left: float = 0.0


func _ready() -> void:
	var pool: Array[SpawnEntry] = (GameState.map as MapData).enemy_pool if GameState.map else []
	for node: Node in get_tree().get_nodes_in_group("map_regions"):
		var region: MapRegion = node as MapRegion
		_regions.append(region)
		region.setup(pool)
		region.progress_changed.connect(_report)
		region.completed.connect(_on_region_completed)
		if _regions_on_compass():
			Compass.track(region, Compass.QUEST)
	for node: Node in get_tree().get_nodes_in_group("interactables"):
		var interactable: Interactable = node as Interactable
		if interactable and interactable.action == &"cart":
			_cart = interactable
			_cart.interacted.connect(_on_cart)
	_report()


## Whether the zones are what the compass points at. A hunt points at its monster instead.
func _regions_on_compass() -> bool:
	return true


func _physics_process(delta: float) -> void:
	_report_left -= delta
	if _report_left <= 0.0:
		_report_left = REPORT_REFRESH
		_report()
	if _cart_armed_left > 0.0:
		_cart_armed_left -= delta
		if _cart_armed_left <= 0.0:
			_cart.refresh_prompt()


func _on_cart(_player: Player) -> void:
	if _cart_armed_left > 0.0:
		cart_taken.emit()
		return
	_cart_armed_left = CART_CONFIRM_TIME
	_cart.set_prompt_text(tr("UI_CART_CONFIRM") % InputHints.key_for("interact"))


## Inside an unfinished region: its goal. Anywhere else: how many regions are done (the compass shows where).
func _report() -> void:
	if not is_inside_tree(): # Regions report one last time as the map unloads.
		return
	for region: MapRegion in _regions:
		if region.player_inside and not region.done:
			_report_progress(region.progress, region.goal_amount(), region.hud_text())
			return
	_report_progress(_done_count(), _regions.size(), REGIONS_KEY)


func _done_count() -> int:
	return _regions.filter(func(region: MapRegion) -> bool: return region.done).size()


func _on_region_completed() -> void:
	for region: MapRegion in _regions:
		if region.done:
			Compass.untrack(region)
	_report()
	if not _finished and _done_count() == _regions.size():
		_finished = true
		_complete()
