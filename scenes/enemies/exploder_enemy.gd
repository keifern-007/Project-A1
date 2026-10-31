class_name ExploderEnemy
extends Enemy
## Waddles up and bursts into a poison cloud (Puffcap).
## IDLE -> APPROACH -> SWELL (puffs up; a ring shows the blast and a disc fills it as the burst nears)
## -> bursts: spawns a PoisonCloud and is gone (no kill credit: nobody killed it).
## Once it starts swelling it can't stop, so walk out of the ring. Killing it first pops it harmlessly.

enum State { IDLE, APPROACH, SWELL }

const SWELL_SCALE: float = 1.5

var state: State = State.IDLE

var _state_time: float = 0.0

@onready var puff: Node3D = $Visual/Puff
@onready var blast_marker: Node3D = $BlastMarker
@onready var blast_fill: MeshInstance3D = $BlastMarker/Fill


func _ready() -> void:
	super._ready()
	blast_marker.visible = false


func _behave(delta: float) -> void:
	_state_time += delta
	match state:
		State.IDLE:
			stand_still()
			target = find_nearest_player()
			if target and (hunt_from_start or flat_distance_to(target) <= data.detection_range):
				_change_state(State.APPROACH)
		State.APPROACH:
			if not refresh_target():
				_change_state(State.IDLE)
			elif flat_distance_to(target) <= data.attack_range:
				_change_state(State.SWELL)
			else:
				walk(flat_direction_to(target))
		State.SWELL:
			stand_still()
			var t: float = minf(_state_time / data.attack_windup, 1.0)
			blast_fill.scale = Vector3(t, 1.0, t)
			if t >= 1.0:
				_burst()


func _change_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	if new_state == State.SWELL:
		blast_marker.visible = true
		blast_fill.scale = Vector3(0.01, 1.0, 0.01)
		# Swelling is the telegraph: it grows (and wobbles) until it bursts.
		var swell: Tween = restart_tween()
		swell.tween_property(puff, "scale", Vector3.ONE * SWELL_SCALE, data.attack_windup) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _burst() -> void:
	if data.burst_scene:
		var cloud: PoisonCloud = data.burst_scene.instantiate()
		var power: int = stats.get_attack_power()
		cloud.setup(power, roundi(power * data.cloud_damage_fraction), data.cloud_duration)
		get_parent().add_child(cloud)
		cloud.global_position = Vector3(global_position.x, 0.0, global_position.z)
	_shut_down()
	status.clear()
	queue_free()


func _stop_attacking() -> void:
	blast_marker.visible = false
