class_name SkillCasterComponent
extends Node
## Holds a loadout of skills (slot 0 = skill_1 action) and their cooldowns, plus an optional
## skill-based basic attack (e.g. the Mystic's Magic Bolt) with its own cooldown.
## Skills cost stamina (physical) or mana (magic). Skills with a cast_time wind up first:
## paid when the wind-up starts, fired when it ends, refunded if cancelled (dodge).

const BASIC_SLOT: int = -1

signal skill_used(slot: int, skill: SkillData)
signal basic_attacked ## Hook for the basic attack's sound.
signal cast_started(skill: SkillData, duration: float) ## Hook for a casting sound; the HUD shows a bar.
signal cast_ended(completed: bool)

## Optional. Effect damage = attack_power × the skill's damage_multiplier.
@export var stats: StatsComponent
@export var stamina: MeterComponent ## Paid by physical skills. Optional (enemies, tests).
@export var mana: MeterComponent ## Paid by magic skills. Optional.
@export var skills: Array[SkillData] = []
## If set, the attack button casts this instead of a melee swing. Its cooldown = attack rate.
## Basic attacks are always free.
@export var basic_attack: SkillData

## 1.3 = cooldowns tick 30% faster (passives, later buffs). Not used for the basic attack.
var cooldown_speed: float = 1.0
## Per-skill multipliers from talents: SkillData -> float (missing = 1.0).
var skill_damage_mods: Dictionary = {}
var skill_cooldown_mods: Dictionary = {}

var _cooldowns: Array[float] = []
var _basic_left: float = 0.0
var _cast: Dictionary = {} # While casting: slot (BASIC_SLOT = basic attack), skill, caster, direction, world, left.


func _ready() -> void:
	set_skills(skills)


## Replaces the loadout (character signatures + weapon skills) and resets cooldowns.
func set_skills(new_skills: Array[SkillData]) -> void:
	skills = new_skills
	_cooldowns.resize(skills.size())
	_cooldowns.fill(0.0)


func _physics_process(delta: float) -> void:
	_basic_left = maxf(_basic_left - delta, 0.0)
	for i: int in _cooldowns.size():
		_cooldowns[i] = maxf(_cooldowns[i] - delta * cooldown_speed, 0.0)
	if is_casting():
		_cast["left"] -= delta
		if _cast["left"] <= 0.0:
			_finish_cast()


## Seconds until the slot is ready again. The HUD reads this.
func get_cooldown_left(slot: int) -> float:
	return _cooldowns[slot] if slot < _cooldowns.size() else 0.0


func basic_ready() -> bool:
	return _basic_left == 0.0


func is_casting() -> bool:
	return not _cast.is_empty()


## 0..1 progress of the current cast (HUD bar).
func cast_progress() -> float:
	if not is_casting():
		return 0.0
	return 1.0 - _cast["left"] / maxf((_cast["skill"] as SkillData).cast_time, 0.01)


func casting_skill() -> SkillData:
	return _cast.get("skill")


## The caster keeps aiming while casting; the skill fires where they aim at the end.
func update_cast_direction(direction: Vector3) -> void:
	if is_casting() and direction != Vector3.ZERO:
		_cast["direction"] = direction


## Which meter pays for a skill (null = free).
func meter_for(skill: SkillData) -> MeterComponent:
	return mana if skill.kind == SkillData.Kind.MAGIC else stamina


func can_afford(skill: SkillData) -> bool:
	var meter: MeterComponent = meter_for(skill)
	return skill.cost <= 0.0 or meter == null or meter.has(skill.cost)


## Casts the skill in `slot` from the caster's position (or starts casting it).
## Returns true if it was cast or the cast started.
func try_cast(slot: int, caster: Node3D, direction: Vector3, world: Node) -> bool:
	if is_casting() or slot >= skills.size() or skills[slot] == null or _cooldowns[slot] > 0.0:
		return false
	var skill: SkillData = skills[slot]
	if not can_afford(skill):
		return false
	if skill.cost > 0.0 and meter_for(skill):
		meter_for(skill).spend(skill.cost)
	if skill.cast_time > 0.0:
		_cast = { "slot": slot, "skill": skill, "caster": caster, "direction": direction, "world": world,
			"left": skill.cast_time }
		cast_started.emit(skill, skill.cast_time)
		return true
	_fire(slot, skill, caster, direction, world)
	return true


## Stops the current cast and refunds its cost (e.g. the player dodged).
func cancel_cast() -> void:
	if not is_casting():
		return
	var skill: SkillData = _cast["skill"]
	if meter_for(skill):
		meter_for(skill).restore(skill.cost)
	_cast = {}
	cast_ended.emit(false)


## Fires the basic attack skill (ranged characters). Free. Returns true if it fired.
func try_basic(caster: Node3D, direction: Vector3, world: Node) -> bool:
	if is_casting() or basic_attack == null or _basic_left > 0.0 or direction == Vector3.ZERO:
		return false
	if basic_attack.cast_time > 0.0:
		_cast = { "slot": BASIC_SLOT, "skill": basic_attack, "caster": caster, "direction": direction, "world": world,
			"left": basic_attack.cast_time }
		cast_started.emit(basic_attack, basic_attack.cast_time)
		return true
	_fire(BASIC_SLOT, basic_attack, caster, direction, world)
	return true


## A skill's cooldown after talents. The HUD uses it for the bar's full length.
func cooldown_of(skill: SkillData) -> float:
	return skill.cooldown * maxf(skill_cooldown_mods.get(skill, 1.0), 0.1)


func _finish_cast() -> void:
	var cast: Dictionary = _cast
	_cast = {}
	if is_instance_valid(cast["caster"]):
		_fire(cast["slot"], cast["skill"], cast["caster"], cast["direction"], cast["world"])
	cast_ended.emit(true)


func _fire(slot: int, skill: SkillData, caster: Node3D, direction: Vector3, world: Node) -> void:
	_spawn(skill, caster, direction, world)
	if slot == BASIC_SLOT:
		_basic_left = cooldown_of(skill)
		basic_attacked.emit()
		return
	_cooldowns[slot] = cooldown_of(skill)
	skill_used.emit(slot, skill)


func _spawn(skill: SkillData, caster: Node3D, direction: Vector3, world: Node) -> void:
	var effect: SkillEffect = skill.effect_scene.instantiate()
	var attack_power: int = stats.get_attack_power() if stats else 0
	effect.damage = roundi(attack_power * skill.damage_multiplier * skill_damage_mods.get(skill, 1.0))
	effect.element = skill.element
	effect.direction = direction
	effect.caster = caster
	world.add_child(effect)
	effect.global_position = caster.global_position
