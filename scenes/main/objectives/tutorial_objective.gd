class_name TutorialObjective
extends Objective
## The Field Guide's practice run: one lesson at a time, each waits until you've really done it.
## Nothing here reaches the save (RetroView skips the results), and you can't die or spend potions.
## Lessons: walk, attack, dodge, skills, gather, a real fight, then a guide to the camp's stations.

## step = which lesson; the text goes to the TutorialBox through RetroView.
signal step_shown(number: int, total: int, text: String, tip: String)
signal guide_requested

enum Step { MOVE, ATTACK, DODGE, SKILL, GATHER, FIGHT, GUIDE }

const GOBLIN: PackedScene = preload("res://scenes/enemies/goblin.tscn")
const DROP_ZONE: PackedScene = preload("res://scenes/bosses/moves/drop_zone.tscn")
const LESSONS: int = 6 ## The camp guide at the end isn't counted.
const WALK_SPOT: Vector3 = Vector3(-7.0, 0.0, 3.0)
const TARGET_SPOT: Vector3 = Vector3(-2.0, 0.0, 3.0)
const GATHER_SPOT: Vector3 = Vector3(-1.0, 0.0, 7.0)
const FIGHT_SPOTS: Array[Vector3] = [Vector3(8.0, 0.0, -2.0), Vector3(0.0, 0.0, -9.0), Vector3(8.0, 0.0, 6.0)]
const REACH_DISTANCE: float = 1.5
const DAMAGE_TAKEN: float = 0.5 ## New players get hit less here.
const TOP_UP_BELOW: float = 0.35 ## Healed back to full below this much HP, so nobody dies learning.
const DODGES_NEEDED: int = 2
const MAX_STRIKES: int = 6 ## Then the lesson moves on anyway, so nobody gets stuck on it.
const STRIKE_WARNING: float = 1.8 ## Seconds from the ring appearing to impact.
const STRIKE_SETTLE: float = 0.25 ## Wait after impact before judging, so the hit has landed.
const STRIKE_PAUSE: float = 1.0
const STRIKE_RADIUS: float = 1.6
const STRIKE_DAMAGE: int = 6

var _step: Step = Step.MOVE
var _player: Player
var _world: Node
var _walk_ring: Node3D
var _target: Enemy
var _fighters_left: int = 0
var _dodges: int = 0
var _strikes: int = 0
var _strike_left: float = 0.0
var _pause_left: float = 0.0
var _rolled: bool = false
var _hit: bool = false


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("players")
	_world = _player.get_parent()
	_player.consumables.locked = true
	_player.hurtbox.damage_taken_multiplier *= DAMAGE_TAKEN
	_player.health.health_changed.connect(_on_health_changed)
	_player.health.damaged.connect(func(_amount: int) -> void: _hit = true)
	_player.dodged.connect(func() -> void: _rolled = true)
	_player.skill_caster.skill_used.connect(_on_skill_used)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.resource_harvested.connect(_on_harvested)
	_enter(Step.MOVE)


## The player closed the camp guide: the tutorial is over.
func finish() -> void:
	_complete()


func _physics_process(delta: float) -> void:
	match _step:
		Step.MOVE:
			if _flat_distance(_player.global_position, WALK_SPOT) <= REACH_DISTANCE:
				_walk_ring.queue_free()
				_enter(Step.ATTACK)
		Step.DODGE:
			_process_strikes(delta)


func _enter(step: Step) -> void:
	_step = step
	_report_progress(mini(step + 1, LESSONS), LESSONS)
	match step:
		Step.MOVE:
			_walk_ring = _make_walk_ring()
			_show("TUT_MOVE", "TUT_MOVE_TIP", _keys(["move_up", "move_left", "move_down", "move_right"]))
		Step.ATTACK:
			_target = _spawn_goblin(TARGET_SPOT, false)
			_show("TUT_ATTACK", "TUT_ATTACK_TIP", InputHints.key_for("attack"))
		Step.DODGE:
			_show_dodge("TUT_DODGE_TIP")
			_pause_left = STRIKE_PAUSE
		Step.SKILL:
			_player.mana.restore(_player.mana.max_value)
			_player.stamina.restore(_player.stamina.max_value)
			_target = _spawn_goblin(_near_player(), false)
			_show("TUT_SKILL", "TUT_SKILL_TIP", _keys(["skill_1", "skill_2", "skill_3", "skill_4"]))
		Step.GATHER:
			var node: GatherNode = data.gather_node_scene.instantiate()
			node.gather_material = data.gather_material
			node.position = GATHER_SPOT
			_world.add_child(node)
			_show("TUT_GATHER", "TUT_GATHER_TIP", InputHints.key_for("interact"))
		Step.FIGHT:
			_fighters_left = FIGHT_SPOTS.size()
			for spot: Vector3 in FIGHT_SPOTS:
				_spawn_goblin(spot, true)
			_show("TUT_FIGHT", "TUT_FIGHT_TIP", "")
		Step.GUIDE:
			_player.input.enabled = false
			guide_requested.emit()


func _show(text_key: String, tip_key: String, key_text: String) -> void:
	var text: String = tr(text_key) % key_text if key_text != "" else tr(text_key)
	step_shown.emit(_step + 1, LESSONS, text, tr(tip_key))


func _show_dodge(tip_key: String) -> void:
	step_shown.emit(_step + 1, LESSONS, tr("TUT_DODGE") % [InputHints.key_for("dodge"), _dodges, DODGES_NEEDED], tr(tip_key))


# One ring at a time under the player. A strike counts if they rolled and weren't hit.
func _process_strikes(delta: float) -> void:
	if _pause_left > 0.0:
		_pause_left -= delta
		if _pause_left <= 0.0:
			_start_strike()
		return
	_strike_left -= delta
	if _strike_left > 0.0:
		return
	var dodged: bool = _rolled and not _hit
	if dodged:
		_dodges += 1
	if _dodges >= DODGES_NEEDED or _strikes >= MAX_STRIKES:
		_enter(Step.SKILL)
		return
	_show_dodge("TUT_DODGE_NICE" if dodged else "TUT_DODGE_MISS")
	_pause_left = STRIKE_PAUSE


func _start_strike() -> void:
	_strikes += 1
	_rolled = false
	_hit = false
	_strike_left = STRIKE_WARNING + STRIKE_SETTLE
	var zone: DropZone = DROP_ZONE.instantiate()
	var spot: Vector3 = _player.global_position
	spot.y = 0.0
	zone.setup(spot, STRIKE_RADIUS, STRIKE_WARNING, STRIKE_DAMAGE, Element.Type.PHYSICAL, 4.0, null, 0.0)
	_world.add_child(zone)


func _on_enemy_killed(_enemy: Node) -> void:
	match _step:
		Step.ATTACK:
			_enter(Step.DODGE)
		Step.FIGHT:
			_fighters_left -= 1
			if _fighters_left <= 0:
				_enter(Step.GUIDE)


func _on_skill_used(_slot: int, _skill: SkillData) -> void:
	if _step != Step.SKILL:
		return
	if is_instance_valid(_target) and not _target.dead:
		_target.despawn()
	_enter(Step.GATHER)


func _on_harvested(_material: Resource, _amount: int) -> void:
	if _step == Step.GATHER:
		_enter(Step.FIGHT)


# Top up on the next frame, after the hit that caused this has finished.
func _on_health_changed(current: int, maximum: int) -> void:
	if current > 0 and current < maximum * TOP_UP_BELOW:
		_player.health.heal.call_deferred(maximum)


func _spawn_goblin(spot: Vector3, hunting: bool) -> Enemy:
	var goblin: Enemy = GOBLIN.instantiate()
	goblin.hunt_from_start = hunting
	goblin.position = spot
	_world.add_child(goblin)
	goblin.set_physics_process(hunting) # A practice target just stands there.
	return goblin


## A clear spot for the skill lesson's target: 5 m from the player, toward the middle of the map.
func _near_player() -> Vector3:
	var flat: Vector3 = _player.global_position
	flat.y = 0.0
	var to_center: Vector3 = -flat.normalized() if flat.length() > 0.5 else Vector3.RIGHT
	return flat + to_center * 5.0


func _make_walk_ring() -> Node3D:
	var ring: Node3D = Node3D.new()
	ring.position = WALK_SPOT
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.9, 0.3)
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = 1.05
	mesh.outer_radius = 1.3
	mesh.material = material
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.1
	ring.add_child(mesh_instance)
	var label: Label3D = Label3D.new()
	label.text = tr("TUT_WALK_HERE")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 24
	label.outline_size = 8
	label.pixel_size = 0.015
	label.position.y = 1.2
	ring.add_child(label)
	_world.add_child(ring)
	return ring


func _keys(actions: Array[String]) -> String:
	var keys: Array[String] = []
	for action: String in actions:
		keys.append(InputHints.key_for(action))
	return " ".join(keys)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
