class_name HazardComponent
extends Node
## The boss hazard on this hero: starts when the boss appears (if the mission has one), ends when it
## dies. A counter potion cures it and protects for a while. The Player creates this.

var stamina: MeterComponent
var health: HealthComponent
var stats: StatsComponent
var hazard: HazardData = null ## Active right now. null = none.

var _ward_left: float = 0.0
var _tick_left: float = 0.0
var _shrunk: float = 0.0 ## Share of max HP lost so far.


func _ready() -> void:
	EventBus.boss_spawned.connect(func(_boss: Node) -> void: _begin())
	EventBus.boss_defeated.connect(func(_boss: Node) -> void: _end())


func is_warded() -> bool:
	return _ward_left > 0.0


## True if this potion's ward would do anything right now, so it can't be wasted.
func can_ward(against: HazardData) -> bool:
	return hazard != null and hazard == against


## Cures what the hazard has done so far, and holds it off for `seconds`.
func ward(against: HazardData, seconds: float) -> void:
	if not can_ward(against):
		return
	_ward_left = seconds
	_tick_left = hazard.shrink_interval
	_shrunk = 0.0
	_apply_max_health()


## HUD line: says what's on you in words, e.g. "! Deep Cold: stamina refills far slower".
func status_text() -> String:
	if hazard == null:
		return ""
	if is_warded():
		return tr("HUD_HAZARD_WARDED") % [tr(hazard.name_key), ceili(_ward_left)]
	return "! %s: %s" % [tr(hazard.name_key), tr(hazard.effect_key)]


func _physics_process(delta: float) -> void:
	if hazard == null or health.is_dead:
		return
	_ward_left = maxf(_ward_left - delta, 0.0)
	var slowed: bool = hazard.kind == HazardData.Kind.SLOW_STAMINA and not is_warded()
	stamina.set_regen_modifier(&"hazard", hazard.stamina_regen_scale if slowed else 1.0)
	if hazard.kind != HazardData.Kind.SHRINK_MAX_HP or is_warded():
		return
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = hazard.shrink_interval
		_shrunk = minf(_shrunk + hazard.shrink_per_tick, hazard.shrink_limit)
		_apply_max_health()


func _begin() -> void:
	var objective: ObjectiveData = GameState.objective as ObjectiveData
	hazard = objective.hazard if objective else null
	if hazard:
		_tick_left = hazard.shrink_interval


func _end() -> void:
	hazard = null
	_ward_left = 0.0
	_shrunk = 0.0
	stamina.set_regen_modifier(&"hazard", 1.0)
	_apply_max_health()


# From the stats each time, so a Run Level gained during the fight still counts.
func _apply_max_health() -> void:
	health.set_max_health(roundi(stats.max_health * (1.0 - _shrunk)), false)
