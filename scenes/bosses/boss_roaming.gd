class_name BossRoaming
extends RefCounted
## A hunted boss between fights (Monster Hunter style). It wanders from one roam point to another,
## resting at each, and notices a hero who comes close (or hits it). Badly hurt, it limps off to a far
## roam point and rests there. The Boss calls process() while its state is ROAM or FLEE.
## Picks use the run RNG, so co-op stays in sync.

const WANDER_SPEED: float = 0.6 ## Share of its normal speed while wandering.
const REST_TIME: Vector2 = Vector2(5.0, 9.0) ## Seconds it waits at each roam point.
const FLEE_REST: float = 12.0 ## Rest after fleeing: the window to catch up.
const ARRIVED: float = 3.0
const TURN_BOOST: float = 2.0 ## Turns faster than in a fight, so it follows paths round corners.
const STUCK_CHECK: float = 1.5 ## Seconds between progress checks.
const STUCK_DISTANCE: float = 0.75 ## Less than this in a check = stuck.
const DETOUR_TIME: float = 0.8

var _boss: Boss
var _route: EnemyPath
var _goal: Vector3
var _rest_left: float = 0.0
var _stuck_timer: float = 0.0
var _last_position: Vector3
var _detour: Vector3 = Vector3.ZERO
var _detour_left: float = 0.0


func _init(boss: Boss) -> void:
	_boss = boss
	_route = EnemyPath.new(boss, true)
	_goal = boss.global_position
	_last_position = boss.global_position
	_rest_left = GameState.rng.randf_range(REST_TIME.x, REST_TIME.y)


func process(delta: float) -> void:
	if _boss.state == Boss.State.ROAM:
		var hero: Node3D = Targeting.nearest_player(_boss)
		if hero and Targeting.flat_distance(_boss.global_position, hero.global_position) <= _boss.notice_range:
			_boss.engage(hero)
			return
		if _rest_left > 0.0:
			_rest_left -= delta
			_boss.stand()
			return
	if Targeting.flat_distance(_boss.global_position, _goal) <= ARRIVED:
		if _boss.state == Boss.State.FLEE:
			_boss.end_flee()
			_rest_left = FLEE_REST
		else:
			_rest_left = GameState.rng.randf_range(REST_TIME.x, REST_TIME.y)
			_pick_next()
		_boss.stand()
		return
	var speed_share: float = _boss.flee_speed if _boss.state == Boss.State.FLEE else WANDER_SPEED
	var direction: Vector3 = _route.direction_to(_goal, delta)
	if _detour_left > 0.0:
		_detour_left -= delta
		direction = _detour
	_boss.walk_along(direction, _boss.data.move_speed * speed_share, delta * TURN_BOOST)
	_check_stuck(direction, delta)


## Routes keep about half a metre from obstacles, but a boss is far wider: if it stops making
## progress (snagged on a tree at a corner), it steps sideways for a moment and carries on.
func _check_stuck(direction: Vector3, delta: float) -> void:
	_stuck_timer += delta
	if _stuck_timer < STUCK_CHECK:
		return
	var moved: float = Targeting.flat_distance(_boss.global_position, _last_position)
	_stuck_timer = 0.0
	_last_position = _boss.global_position
	if moved < STUCK_DISTANCE and _detour_left <= 0.0:
		var side: float = 1.0 if GameState.rng.randf() < 0.5 else -1.0
		_detour = Vector3(-direction.z, 0.0, direction.x) * side
		_detour_left = DETOUR_TIME


## Off to the roam point farthest from the hero who hurt it.
func start_flee(from: Node3D) -> void:
	var away_from: Vector3 = from.global_position if from else _boss.global_position
	var best: float = -1.0
	for point: Vector3 in _boss.roam_points:
		var distance: float = Targeting.flat_distance(point, away_from)
		if distance > best:
			best = distance
			_goal = point


## The hero got away: back to wandering, from where it is.
func lose_track() -> void:
	_rest_left = 0.0
	_pick_next()


func _pick_next() -> void:
	var options: Array[Vector3] = []
	for point: Vector3 in _boss.roam_points:
		if Targeting.flat_distance(point, _boss.global_position) > ARRIVED * 2.0:
			options.append(point)
	if not options.is_empty():
		_goal = options[GameState.rng.randi_range(0, options.size() - 1)]
