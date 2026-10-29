class_name Player
extends CharacterBody3D
## The chosen character (stats, speed, look, skills) + movement relative to the camera, a dodge roll with invulnerability frames (i-frames),
## a basic melee attack, skills and the loadout's consumable.

signal dodged
signal collected(pickup: Pickup) ## Hook for pickup sounds.

@export var move_speed: float = 6.0
@export var acceleration: float = 60.0 ## How fast we reach move_speed. Higher = snappier.
@export var turn_speed: float = 14.0
@export var cast_move_factor: float = 0.4 ## Walking speed while casting a skill with a cast time.
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


func _ready() -> void:
	set_controlled(controlled)
	_apply_character(character.data)
	skill_caster.set_skills(character.skill_loadout())
	skill_caster.basic_attack = character.data.basic_attack
	health.died.connect(_on_died)
	hurtbox.hurt.connect(_on_hurt)
	hurtbox.damage_taken_multiplier *= GameState.damage_taken_multiplier() # On top of passives (Bulwark).


func _physics_process(delta: float) -> void:
	_dodge_cooldown_left = maxf(_dodge_cooldown_left - delta, 0.0)
	var move_dir: Vector3 = input.get_move_direction()

	if input.is_dodge_pressed() and _dodge_cooldown_left == 0.0 and _dash_time_left == 0.0:
		skill_caster.cancel_cast() # Dodging out of a cast refunds it.
		_start_dodge(move_dir)

	if combat_enabled and _dash_time_left == 0.0:
		_handle_combat()

	if _dash_time_left > 0.0:
		_dash_time_left = maxf(_dash_time_left - delta, 0.0)
		velocity.x = _dash_direction.x * _dash_speed
		velocity.z = _dash_direction.z * _dash_speed
		if _dash_time_left == 0.0:
			_end_dash()
	else:
		var speed: float = move_speed * (cast_move_factor if skill_caster.is_casting() else 1.0)
		var target: Vector3 = move_dir * speed
		velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
		# While attacking, keep facing the attack instead of the walk direction.
		if move_dir != Vector3.ZERO and melee.can_attack() and skill_caster.basic_ready():
			_face(move_dir, delta)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()


## Speed and dodge from the character; stats were already set by CharacterComponent.
func _apply_character(data: CharacterData) -> void:
	move_speed = data.move_speed * talents.move_speed_multiplier()
	dodge_cooldown = data.dodge_cooldown
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
	if skill_caster.is_casting(): # Keep aiming while casting; nothing else until it fires.
		var aim: Vector3 = _aim_direction()
		skill_caster.update_cast_direction(aim)
		visual.rotation.y = atan2(-aim.x, -aim.z)
		return
	if input.is_attack_pressed():
		var dir: Vector3 = _aim_direction()
		var attacked: bool = false
		if skill_caster.basic_attack: # Ranged characters (Mystic) cast their basic attack skill.
			attacked = skill_caster.try_basic(self, dir, get_parent())
		else:
			attacked = melee.attack(dir)
		if attacked:
			visual.rotation.y = atan2(-dir.x, -dir.z)
	for slot: int in range(1, 5):
		if input.is_skill_pressed(slot):
			skill_caster.try_cast(slot - 1, self, _aim_direction(), get_parent())
	if input.is_consumable_pressed():
		consumables.try_use()


## Mouse/right stick if aiming, otherwise the way we're facing.
func _aim_direction() -> Vector3:
	var aim: Vector3 = input.get_aim_direction(global_position)
	return aim if aim != Vector3.ZERO else -visual.global_basis.z


func _face(dir: Vector3, delta: float) -> void:
	var target_yaw: float = atan2(-dir.x, -dir.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, turn_speed * delta)


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
	input.enabled = false
	hurtbox.invulnerable = true
	# Tip over forward: a shape change, readable without color.
	create_tween().tween_property(visual, "rotation:x", -PI / 2.0, 0.4) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	EventBus.player_died.emit(self)
