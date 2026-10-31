class_name AreaRainMove
extends BossMove
## Things fall from the sky onto several spots (Icicle Rain). The first spot is where the target
## stands, the others are scattered around it with the run RNG. Each spot is a DropZone: a ring with
## a disc filling it until impact, then a hit and optionally an obstacle left behind for a while
## (icicles become temporary walls), so the fight reshapes the arena.

@export var drop_zone_scene: PackedScene
@export var zone_count: int = 5
@export var phase_two_extra_zones: int = 3
@export var zone_radius: float = 1.6
@export var spread: float = 6.0 ## Extra spots land up to this far from the target.
@export var stagger: float = 0.12 ## Seconds between impacts, so it reads as a rain, not one hit.
@export var obstacle_scene: PackedScene ## Optional: left at each spot (layer 1 = blocks movement).
@export var obstacle_time: float = 6.0
@export var show_falling: bool = true ## The falling object (icicle) in the last moments. Off for ground effects.

var _zones: Array = [] # Untyped: it can hold zones that were already freed.


func start(boss: Boss, target: Node3D, real_windup: float) -> void:
	var still_there: Array = []
	for zone: Variant in _zones:
		if is_instance_valid(zone):
			still_there.append(zone)
	_zones = still_there
	var center: Vector3 = boss.ground_point(target.global_position) if is_instance_valid(target) else boss.global_position
	var count: int = zone_count + (phase_two_extra_zones if boss.phase >= 2 else 0)
	var rng: RandomNumberGenerator = GameState.rng
	for i: int in count:
		var spot: Vector3 = center
		if i > 0:
			var angle: float = rng.randf() * TAU
			var distance: float = rng.randf_range(zone_radius * 1.5, spread)
			spot += Vector3(cos(angle), 0.0, sin(angle)) * distance
		var zone: DropZone = drop_zone_scene.instantiate()
		zone.setup(spot, zone_radius, real_windup + i * stagger, damage, element, knockback,
			obstacle_scene, obstacle_time)
		zone.show_falling = show_falling
		boss.get_parent().add_child(zone)
		_zones.append(zone)


## The zones hit on their own timers; the boss just slams the ground.
func strike(boss: Boss) -> void:
	super.strike(boss)


## The boss died: impacts that haven't landed yet are called off (walls already up stay).
func cancel() -> void:
	for zone: Variant in _zones:
		if is_instance_valid(zone):
			(zone as DropZone).cancel()
	_zones.clear()
