class_name Player
extends CharacterBody3D
## The chosen character (stats, speed, look, skills) + movement relative to the camera, a dodge roll with invulnerability frames (i-frames),
## a basic melee attack, skills and the loadout's consumable.
## Every attack is wind-up (slow walk, keeps aiming, dodging cancels and refunds) -> fires ->
## commit (locked in, no dodging), Dark Souls style. Taking a hit doesn't interrupt either.
## Basic attacks and dodging spend stamina (amounts from CharacterData); a cancelled wind-up refunds it.

const LEAN_BACK: float = 0.436 ## ~25 degrees, in radians. The wind-up telegraph.
const LEAN_FORWARD: float = -0.262 ## ~-15 degrees. The strike.
const LEAN_STRIKE_TIME: float = 0.05
const DODGE_BUFFER: float = 0.2 ## A dodge pressed this soon before the commit ends still happens.
const HEAVY_WEAPON: float = 1.3 ## Main hand wind-up multiplier from which hits break guards.

signal dodged
signal stamina_short ## An attack or dodge was refused for lack of stamina (HUD shows 'No stamina').
signal collected(pickup: Pickup) ## Hook for pickup sounds.

@export var move_speed: float = 6.0
@export var acceleration: float = 60.0 ## How fast we reach move_speed. Higher = snappier.
@export var turn_speed: float = 14.0
@export var cast_move_factor: float = 0.4 ## Walking speed during an attack's wind-up.
@export var commit_move_factor: float = 0.15 ## Walking speed while committed to an attack.
## Off in the camp: you walk and interact, but don't swing at the campfire.
@export var combat_enabled: bool = true
## False = an NPC body (the heroes you aren't playing in camp): no device input, not in "players".
@export var controlled: bool = true

@export_group("Feel")
@export var hurt_shake: float = 0.5
@export var hurt_hit_stop: float = 0.08

@export_group("Dodge")
@export var dodge_speed: float = 16.0
@export var dodge_duration: float = 0.2
@export var dodge_cooldown: float = 0.6

## A dash = the dodge roll, or a skill moving us (Dash Strike). Combat waits until it ends.
var _dash_time_left: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO
var _dash_speed: float = 0.0
var _dash_invulnerable: bool = false
var _dodge_cooldown_left: float = 0.0
var _dodge_buffer_left: float = 0.0
var _commit_left: float = 0.0
var _attack_stamina_cost: float = 0.0
var _speed_modifiers: Dictionary = {} # source -> walk speed multiplier (quicksand...).
var _dodge_stamina_cost: float = 0.0
var _lean_tween: Tween
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var input: PlayerInput = $PlayerInput
@onready var character: CharacterComponent = $CharacterComponent
@onready var visual: Node3D = $Visual
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var melee: MeleeAttackComponent = $MeleeAttack
@onready var skill_caster: SkillCasterComponent = $SkillCaster
@onready var level: LevelComponent = $LevelComponent
@onready var boosters: BoosterComponent = $BoosterComponent
@onready var consumables: ConsumableComponent = $ConsumableComponent
@onready var passives: PassiveComponent = $PassiveComponent
@onready var talents: TalentComponent = $TalentComponent
@onready var stamina: MeterComponent = $StaminaMeter
@onready var mana: MeterComponent = $ManaMeter
## Chill slows us, Freeze stops us (enemy Ice/Poison/Fire hits). Shown above our head as text.
@onready var status: StatusEffectComponent = $StatusEffectComponent


func _ready() -> void:
	set_controlled(controlled)
	_apply_character(character.data)
	skill_caster.set_skills(character.skill_loadout())
	skill_caster.basic_attack = character.data.basic_attack
	var weapon_windup: float = character.weapon_windup_multiplier()
	melee.windup_time *= weapon_windup
	var heavy: bool = weapon_windup >= HEAVY_WEAPON
	melee.hitbox.guard_break = heavy
	for skill: SkillData in character.weapon_skills():
		skill_caster.skill_windup_mods[skill] = weapon_windup
		if heavy:
			skill_caster.guard_break_skills[skill] = true
	health.died.connect(_on_died)
	hurtbox.hurt.connect(_on_hurt)
	hurtbox.damage_taken_multiplier *= GameState.damage_taken_multiplier() # On top of passives (Bulwark).
	melee.windup_started.connect(_lean_into_windup)
	melee.windup_cancelled.connect(_animate_lean.bind(0.0, LEAN_STRIKE_TIME))
	melee.attacked.connect(func() -> void: _commit(melee.commit_time))
	skill_caster.cast_started.connect(func(_skill: SkillData, duration: float) -> void: _lean_into_windup(duration))
	skill_caster.cast_ended.connect(func(completed: bool) -> void:
		if not completed:
			_animate_lean(0.0, LEAN_STRIKE_TIME))
	skill_caster.skill_used.connect(func(_slot: int, skill: SkillData) -> void: _commit(skill.commit_time))
	skill_caster.basic_attacked.connect(func() -> void: _commit(skill_caster.basic_attack.commit_time))


func _physics_process(delta: float) -> void:
	_dodge_cooldown_left = maxf(_dodge_cooldown_left - delta, 0.0)
	_dodge_buffer_left = maxf(_dodge_buffer_left - delta, 0.0)
	_commit_left = maxf(_commit_left - delta, 0.0)
	var move_dir: Vector3 = input.get_move_direction()

	var frozen: bool = status.is_frozen()
	if frozen and is_winding_up():
		_cancel_windup() # Frozen solid: the attack fizzles (refunded).
	if input.is_dodge_pressed():
		_dodge_buffer_left = DODGE_BUFFER
	if _dodge_buffer_left > 0.0 and not frozen and not is_committed() and _dodge_cooldown_left == 0.0 and _dash_time_left == 0.0:
		_dodge_buffer_left = 0.0
		# The wind-up's refund counts, so a dodge out of a wind-up works even on an empty bar.
		if stamina.current + _windup_refund() >= _dodge_stamina_cost:
			_cancel_windup() # Dodging out of a wind-up refunds it.
			stamina.spend(_dodge_stamina_cost)
			_start_dodge(move_dir)
		else:
			stamina_short.emit()

	if combat_enabled and _dash_time_left == 0.0 and not frozen:
		_handle_combat()

	if _dash_time_left > 0.0:
		_dash_time_left = maxf(_dash_time_left - delta, 0.0)
		velocity.x = _dash_direction.x * _dash_speed
		velocity.z = _dash_direction.z * _dash_speed
		if _dash_time_left == 0.0:
			_end_dash()
	else:
		var target: Vector3 = move_dir * move_speed * _attack_move_factor() * status.speed_multiplier() * speed_modifier()
		velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
		# While attacking, keep facing the attack instead of the walk direction.
		if move_dir != Vector3.ZERO and not is_committed() and melee.can_attack() and skill_caster.basic_ready():
			_face(move_dir, delta)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()


## Speed and dodge from the character; stats were already set by CharacterComponent.
func _apply_character(data: CharacterData) -> void:
	move_speed = data.move_speed * talents.move_speed_multiplier()
	dodge_cooldown = data.dodge_cooldown
	_attack_stamina_cost = data.attack_stamina_cost
	_dodge_stamina_cost = data.dodge_stamina_cost
	stamina.configure(data.max_stamina, data.stamina_regen)
	mana.configure(data.max_mana, data.mana_regen, data.mana_per_kill)
	# Placeholder look: tint + silhouette (shape, so it never relies on color alone).
	visual.scale = data.body_scale
	var body: MeshInstance3D = visual.get_node("Body")
	var material: StandardMaterial3D = body.get_surface_override_material(0).duplicate()
	material.albedo_color = data.color
	body.set_surface_override_material(0, material)


## Hands this body to the local player, or makes it an NPC. Only controlled bodies are
## in group "players" (stations, pickups, enemies and the camera look for that group).
func set_controlled(on: bool) -> void:
	controlled = on
	input.enabled = on
	input.scripted_direction = Vector3.ZERO
	if on:
		add_to_group("players")
	elif is_in_group("players"):
		remove_from_group("players")


## Instantly turns to look at a point (NPCs idling toward the campfire).
func face_toward(point: Vector3) -> void:
	var dir: Vector3 = point - global_position
	dir.y = 0.0
	if dir.length() > 0.01:
		visual.rotation.y = atan2(-dir.x, -dir.z)


func is_alive() -> bool:
	return not health.is_dead


## Locked into an attack that already fired: can't dodge or act until it ends.
func is_committed() -> bool:
	return _commit_left > 0.0


func is_winding_up() -> bool:
	return skill_caster.is_casting() or melee.is_winding_up()


## Called by a Pickup when it reaches us.
func collect(pickup: Pickup) -> void:
	if pickup.xp > 0:
		level.add_xp(pickup.xp)
	if pickup.drop_material:
		EventBus.material_obtained.emit(pickup.drop_material, pickup.amount)
	if pickup.booster:
		boosters.apply(pickup.booster)
	collected.emit(pickup)


## Camp stations etc. ask this (one press = one interaction).
func is_interact_just_pressed() -> bool:
	return input.is_interact_pressed() and _dash_time_left == 0.0


## Gather nodes etc. ask this. Dodging cancels it.
func is_interacting() -> bool:
	return input.is_interact_held() and _dash_time_left == 0.0


## Moves us fast in a straight line (dodge roll, Dash Strike). Overrides walking until it ends.
func dash(direction: Vector3, speed: float, duration: float, invulnerable: bool) -> void:
	_dash_direction = direction.normalized()
	_dash_speed = speed
	_dash_time_left = duration
	_dash_invulnerable = invulnerable
	visual.rotation.y = atan2(-_dash_direction.x, -_dash_direction.z)
	if invulnerable:
		hurtbox.invulnerable = true
		_set_ghosted(true)


## Teleports (Blink), briefly invulnerable. The skill checks walls before choosing `target`.
func blink(target: Vector3, invulnerable_time: float) -> void:
	global_position = target
	velocity = Vector3.ZERO
	hurtbox.invulnerable = true
	_set_ghosted(true)
	get_tree().create_timer(invulnerable_time, false, true).timeout.connect(func() -> void:
		if _dash_time_left == 0.0 and is_alive(): # A dodge in between handles its own ending.
			hurtbox.invulnerable = false
			_set_ghosted(false))


func _handle_combat() -> void:
	if is_committed():
		return
	if is_winding_up(): # Keep aiming during the wind-up; nothing else until it fires.
		var aim: Vector3 = _aim_direction()
		skill_caster.update_cast_direction(aim)
		melee.update_windup_direction(aim)
		visual.rotation.y = atan2(-aim.x, -aim.z)
		return
	if input.is_attack_pressed():
		_try_basic_attack()
	for slot: int in range(1, 5):
		if input.is_skill_pressed(slot):
			skill_caster.try_cast(slot - 1, self, _aim_direction(), get_parent())
	if input.is_consumable_pressed():
		consumables.try_use()


## Melee swing or the character's basic attack skill, paid with stamina when it starts.
func _try_basic_attack() -> void:
	var off_cooldown: bool = skill_caster.basic_ready() if skill_caster.basic_attack else melee.can_attack()
	if not off_cooldown:
		return
	if not stamina.has(_attack_stamina_cost):
		stamina_short.emit()
		return
	var dir: Vector3 = _aim_direction()
	var attacked: bool = false
	if skill_caster.basic_attack: # Ranged characters (Mystic) cast their basic attack skill.
		attacked = skill_caster.try_basic(self, dir, get_parent())
	else:
		attacked = melee.start_attack(dir)
	if attacked:
		stamina.spend(_attack_stamina_cost)
		visual.rotation.y = atan2(-dir.x, -dir.z)


## Ground effects slow walking through this (quicksand). Each source sets its own; 1.0 removes it.
## Only the strongest one counts, so overlapping pools never pin you in place.
func set_speed_modifier(source: StringName, multiplier: float) -> void:
	if is_equal_approx(multiplier, 1.0):
		_speed_modifiers.erase(source)
	else:
		_speed_modifiers[source] = multiplier


func speed_modifier() -> float:
	var strongest: float = 1.0
	for multiplier: float in _speed_modifiers.values():
		strongest = minf(strongest, multiplier)
	return strongest


## Mouse/right stick if aiming, otherwise the way we're facing.
func _aim_direction() -> Vector3:
	var aim: Vector3 = input.get_aim_direction(global_position)
	return aim if aim != Vector3.ZERO else -visual.global_basis.z


func _face(dir: Vector3, delta: float) -> void:
	var target_yaw: float = atan2(-dir.x, -dir.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, turn_speed * delta)


func _attack_move_factor() -> float:
	if is_committed():
		return commit_move_factor
	return cast_move_factor if is_winding_up() else 1.0


## Stamina a cancel would give back: only a basic attack still winding up (skills refund themselves).
func _windup_refund() -> float:
	var basic_winding: bool = skill_caster.is_casting() and skill_caster.casting_skill() == skill_caster.basic_attack
	return _attack_stamina_cost if melee.is_winding_up() or basic_winding else 0.0


func _cancel_windup() -> void:
	stamina.restore(_windup_refund())
	skill_caster.cancel_cast()
	melee.cancel_windup()


func _commit(duration: float) -> void:
	_commit_left = duration
	_animate_lean(LEAN_FORWARD, LEAN_STRIKE_TIME)
	_lean_tween.tween_property(visual, "rotation:x", 0.0, maxf(duration, LEAN_STRIKE_TIME))


func _lean_into_windup(duration: float) -> void:
	_animate_lean(LEAN_BACK, duration)


## Leaning is the telegraph: shape/motion, not color, so it reads for everyone.
func _animate_lean(angle: float, duration: float) -> void:
	if _lean_tween:
		_lean_tween.kill()
	_lean_tween = create_tween()
	_lean_tween.tween_property(visual, "rotation:x", angle, duration)


func _start_dodge(move_dir: Vector3) -> void:
	# No input? Dodge the way we're facing.
	var dir: Vector3 = move_dir if move_dir != Vector3.ZERO else -visual.global_basis.z
	_dodge_cooldown_left = dodge_cooldown
	dash(dir, dodge_speed, dodge_duration, true)
	dodged.emit()


func _end_dash() -> void:
	# Drop back to walking speed so the dash ends crisply instead of sliding.
	velocity.x *= move_speed / _dash_speed
	velocity.z *= move_speed / _dash_speed
	if _dash_invulnerable:
		hurtbox.invulnerable = false
		_set_ghosted(false)


## Half-transparent while invulnerable (shape change, not color, so it reads for everyone).
func _set_ghosted(on: bool) -> void:
	for child: Node in visual.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).transparency = 0.5 if on else 0.0


func _on_hurt(_amount: int, hitbox: HitboxComponent) -> void:
	var away: Vector3 = global_position - hitbox.global_position
	away.y = 0.0
	var push: Vector3 = away.normalized() * hitbox.knockback * passives.knockback_taken()
	# Walking acceleration pulls us back to normal quickly, so this is a short shove.
	velocity.x = push.x
	velocity.z = push.z
	GameFeel.shake(hurt_shake)
	GameFeel.hit_stop(get_tree(), hurt_hit_stop)


func _on_died() -> void:
	_cancel_windup() # A dead hero doesn't finish the swing.
	if _lean_tween:
		_lean_tween.kill()
	input.enabled = false
	hurtbox.invulnerable = true
	# Tip over forward: a shape change, readable without color.
	create_tween().tween_property(visual, "rotation:x", -PI / 2.0, 0.4) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	EventBus.player_died.emit(self)
