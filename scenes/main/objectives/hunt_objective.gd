class_name HuntObjective
extends ExpeditionObjective
## Monster Hunter-style hunt on a big map: a boss (data.boss_scene) wanders the zones from the map's
## "boss_spawns" marker, between Marker3Ds in group "roam_points", and limps to another zone when badly
## hurt. Defeating it wins. Zone goals are optional side tasks. The HUD always says where it was last
## seen, in words (zone, distance, direction), so tracking it never depends on spotting it.

var _boss: Boss


func _ready() -> void:
	super._ready()
	EventBus.boss_defeated.connect(_on_boss_defeated)
	_spawn_boss.call_deferred() # After the map's regions and markers are all ready.


func _spawn_boss() -> void:
	var start: Node3D = get_tree().get_first_node_in_group("boss_spawns")
	if start == null:
		push_error("HuntObjective: this map has no Marker3D in group 'boss_spawns'.")
		return
	_boss = data.boss_scene.instantiate()
	for point: Node in get_tree().get_nodes_in_group("roam_points"):
		_boss.roam_points.append((point as Node3D).global_position)
	start.get_parent().add_child(_boss)
	_boss.global_position = start.global_position
	Compass.track(_boss, Compass.BOSS)
	_report()


## The compass points at the monster, not the optional zones.
func _regions_on_compass() -> bool:
	return false


## Zones don't end a hunt; finishing them is optional.
func _on_region_completed() -> void:
	_report()


func _on_boss_defeated(_defeated: Node) -> void:
	if data.boss_drop:
		EventBus.material_obtained.emit(data.boss_drop, data.boss_drop_amount)
	_report_progress(1, 1)
	_complete()


## "Hunt the Thornback 0/1" (the compass shows where), "... (it's fleeing!)" while it runs, and
## while you're in an unfinished zone outside a fight, that zone's side task.
func _report() -> void:
	if not is_inside_tree() or not is_instance_valid(_boss) or _boss.state == Boss.State.DEAD:
		return
	if _boss.state == Boss.State.FLEE:
		_report_progress(0, 1, tr("OBJ_HUNT_FLEEING") % tr(data.name_key))
		return
	if _boss.state == Boss.State.ROAM:
		for region: MapRegion in _regions:
			if region.player_inside and not region.done:
				_report_progress(region.progress, region.goal_amount(), tr("OBJ_SIDE_TASK") % region.hud_text())
				return
	_report_progress(0, 1)
