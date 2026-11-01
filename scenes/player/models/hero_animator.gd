class_name HeroAnimator
extends Node
## Moves a HeroRig every frame. Each joint has a target angle, built from layers: stance, then
## walking, then the current action (wind-up, strike, roll...), and eases toward it. Timings come from
## the real combat signals, so a heavy weapon's slow wind-up looks slow. Purely visual: never touches
## gameplay, and flourishes use their own RNG, never the run seed.
## Joint signs: +X swings an arm or leg forward, -X on a shin bends the knee, +Z moves the right arm out.

enum Action { NONE, WINDUP, STRIKE, ROLL, HURT, DRINK, CHEER, FLOURISH }

const EASE_NORMAL: float = 14.0
const EASE_SNAP: float = 34.0 ## Strikes move fast.
const STRIKE_TIME: float = 0.16
const SPIN_TIME: float = 0.5 ## Whirlwind: one full turn.
const HURT_TIME: float = 0.22
const DRINK_TIME: float = 0.6
const WALK_CYCLE_SPEED: float = 2.1 ## Steps per meter, roughly. Faster heroes step faster.
const FLOURISH_TIME: float = 1.1

var rig: HeroRig
var player: Player

var _joints: Dictionary = {} # name -> Node3D
var _target: Dictionary = {} # name -> Vector3
var _action: Action = Action.NONE
var _action_time: float = 0.0
var _action_length: float = 1.0
var _pose: StringName = &"slash" ## What this attack looks like.
var _side: float = 1.0 ## Which hand punches next, for fists and dual wielding.
var _walk_phase: float = 0.0
var _walk_amount: float = 0.0
var _life: float = 0.0
var _next_flourish: float = 0.0
var _dead: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _robe: Node3D
var _cape: Node3D
var _orb: Node3D


func setup(for_rig: HeroRig, for_player: Player = null) -> void:
	rig = for_rig
	player = for_player
	for joint: String in ["Hips", "Torso", "Head", "ArmR", "ForeR", "ArmL", "ForeL", "ThighR", "ShinR", "ThighL", "ShinL"]:
		_joints[joint] = rig.get_node("%" + joint)
	_robe = rig.get_node_or_null("%Robe")
	_cape = rig.get_node_or_null("%Cape")
	_orb = rig.get_node_or_null("%OrbSpin")
	_rng.randomize()
	_next_flourish = _rng.randf_range(3.0, 9.0)
	if player:
		_connect_player()


func _connect_player() -> void:
	player.melee.windup_started.connect(func(duration: float) -> void: _windup(_weapon_pose(), duration))
	player.melee.windup_cancelled.connect(_stop)
	player.melee.attacked.connect(_strike)
	player.skill_caster.cast_started.connect(func(skill: SkillData, duration: float) -> void:
		_windup(_pose_of(skill), duration))
	player.skill_caster.cast_ended.connect(func(completed: bool) -> void:
		if completed:
			_strike()
		else:
			_stop())
	player.dodged.connect(func() -> void: _start(Action.ROLL, player.dodge_duration))
	player.hurtbox.hurt.connect(func(_amount: int, _hitbox: HitboxComponent) -> void:
		if _action == Action.NONE or _action == Action.FLOURISH:
			_start(Action.HURT, HURT_TIME))
	player.consumables.used.connect(func(_item: ItemData) -> void: _start(Action.DRINK, DRINK_TIME))
	player.health.died.connect(func() -> void: _dead = true)
	EventBus.run_ended.connect(func(victory: bool) -> void:
		if victory and not _dead:
			_start(Action.CHEER, 999.0))


## For previews: a cheer or a flourish on request.
func play_flourish() -> void:
	_start(Action.FLOURISH, FLOURISH_TIME)


func _process(delta: float) -> void:
	if rig == null:
		return
	if player and player.status.is_frozen():
		return # Frozen solid: every joint holds still.
	_life += delta
	_action_time += delta
	if _action != Action.NONE and _action_time >= _action_length and _action != Action.WINDUP:
		_stop()
	_update_walk(delta)
	_target.clear()
	_stance()
	_walking()
	_act()
	if _dead:
		_slump()
	_apply(delta)
	_secondary(delta)
	_maybe_flourish()


func _windup(pose: StringName, duration: float) -> void:
	_pose = pose
	_side = -_side
	_start(Action.WINDUP, maxf(duration, 0.05))


func _strike() -> void:
	_start(Action.STRIKE, SPIN_TIME if _pose == &"spin" else STRIKE_TIME)


func _start(action: Action, length: float) -> void:
	_action = action
	_action_time = 0.0
	_action_length = length
	_joints["Hips"].rotation.x = 0.0


func _stop() -> void:
	_action = Action.NONE
	_joints["Hips"].rotation.x = 0.0
	rig.rotation.y = 0.0
	rig.position.y = 0.0


## Basic attack's look, from what's in the main hand.
func _weapon_pose() -> StringName:
	if rig.two_handed:
		return &"overhead"
	match rig.weapon_kind:
		&"":
			return &"punch"
		&"dagger":
			return &"stab"
		&"wand":
			return &"cast"
	return &"slash"


func _pose_of(skill: SkillData) -> StringName:
	if skill == player.skill_caster.basic_attack:
		return &"cast"
	if skill.anim != &"":
		return skill.anim
	return &"cast" if skill.kind == SkillData.Kind.MAGIC else _weapon_pose()


func _update_walk(delta: float) -> void:
	var speed: float = 0.0
	if player:
		speed = Vector2(player.velocity.x, player.velocity.z).length()
		if player.status.is_frozen():
			speed = 0.0
	_walk_amount = lerpf(_walk_amount, clampf(speed / 3.0, 0.0, 1.0), 1.0 - exp(-10.0 * delta))
	_walk_phase += speed * WALK_CYCLE_SPEED * delta


func _pose_joint(joint: String, angles: Vector3) -> void:
	_target[joint] = angles


func _add(joint: String, angles: Vector3) -> void:
	_target[joint] = _target.get(joint, Vector3.ZERO) + angles


# --- Layers ----------------------------------------------------------------------------------

func _stance() -> void:
	var breath: float = sin(_life * 2.0) * 0.03
	_pose_joint("Torso", Vector3(breath, 0.0, 0.0))
	_pose_joint("Head", Vector3(-breath * 0.6, sin(_life * 0.7) * 0.06, 0.0))
	match rig.style:
		HeroRig.Style.FIGHTER: # Fists up, knees loose, ready.
			_pose_joint("ArmR", Vector3(0.75 + breath, 0.0, 0.22))
			_pose_joint("ForeR", Vector3(1.75, 0.0, 0.0))
			_pose_joint("ArmL", Vector3(0.95 - breath, 0.0, -0.22))
			_pose_joint("ForeL", Vector3(1.85, 0.0, 0.0))
			_pose_joint("Torso", Vector3(0.12 + breath, 0.2, 0.0))
			_pose_joint("Head", Vector3(-0.1, -0.2, 0.0))
			_pose_joint("ThighR", Vector3(0.22, 0.0, 0.05))
			_pose_joint("ShinR", Vector3(-0.35, 0.0, 0.0))
			_pose_joint("ThighL", Vector3(-0.08, 0.0, -0.05))
			_pose_joint("ShinL", Vector3(-0.2, 0.0, 0.0))
		HeroRig.Style.TANK: # Square and planted.
			_pose_joint("ArmR", Vector3(0.1, 0.0, 0.16))
			_pose_joint("ForeR", Vector3(0.35, 0.0, 0.0))
			_pose_joint("ArmL", Vector3(0.1, 0.0, -0.16))
			_pose_joint("ForeL", Vector3(0.35, 0.0, 0.0))
		HeroRig.Style.CASTER: # Upright, one hand held ready.
			_pose_joint("ArmR", Vector3(0.45 + breath, 0.0, 0.12))
			_pose_joint("ForeR", Vector3(0.95, 0.0, 0.0))
			_pose_joint("ArmL", Vector3(0.06, 0.0, -0.1))
			_pose_joint("ForeL", Vector3(0.3, 0.0, 0.0))
	if rig.has_main_hand: # Weapon carried out front.
		_pose_joint("ArmR", Vector3(0.55, 0.0, 0.14))
		_pose_joint("ForeR", Vector3(0.75, 0.0, 0.0))
	if rig.two_handed: # Both hands on a heavy haft.
		_pose_joint("ArmR", Vector3(0.75, 0.0, 0.1))
		_pose_joint("ForeR", Vector3(1.05, 0.0, 0.0))
		_pose_joint("ArmL", Vector3(0.95, 0.0, 0.25))
		_pose_joint("ForeL", Vector3(1.45, 0.0, 0.0))
	if rig.has_off_hand: # A shield or second weapon held forward.
		_pose_joint("ArmL", Vector3(0.7, 0.0, -0.18))
		_pose_joint("ForeL", Vector3(1.15, 0.0, 0.0))
	if player and player.combat_enabled and player.is_interacting(): # Picking a plant: down on one knee.
		_pose_joint("ThighR", Vector3(1.5, 0.0, 0.0))
		_pose_joint("ShinR", Vector3(-1.7, 0.0, 0.0))
		_pose_joint("ThighL", Vector3(0.2, 0.0, 0.0))
		_pose_joint("ShinL", Vector3(-1.5, 0.0, 0.0))
		_pose_joint("ArmR", Vector3(1.0, 0.0, 0.0))
		_pose_joint("ForeR", Vector3(0.4, 0.0, 0.0))
		_add("Torso", Vector3(0.6, 0.0, 0.0))
		rig.position.y = -0.35


func _walking() -> void:
	if _walk_amount < 0.01:
		return
	var swing: float = sin(_walk_phase) * _walk_amount
	var counter: float = cos(_walk_phase) * _walk_amount
	var stride: float = 0.75 if rig.style != HeroRig.Style.TANK else 0.5
	_add("ThighR", Vector3(swing * stride, 0.0, 0.0))
	_add("ThighL", Vector3(-swing * stride, 0.0, 0.0))
	_add("ShinR", Vector3(-maxf(-counter, 0.0) * 1.1, 0.0, 0.0))
	_add("ShinL", Vector3(-maxf(counter, 0.0) * 1.1, 0.0, 0.0))
	_add("ArmR", Vector3(-swing * 0.35, 0.0, 0.0))
	_add("ArmL", Vector3(swing * 0.35, 0.0, 0.0))
	_add("Torso", Vector3(0.1 * _walk_amount, swing * 0.1, 0.0))
	_add("Hips", Vector3(0.0, -swing * 0.08, 0.0))
	rig.position.y = absf(sin(_walk_phase)) * 0.05 * _walk_amount if _action != Action.ROLL else rig.position.y


func _act() -> void:
	var t: float = clampf(_action_time / _action_length, 0.0, 1.0)
	match _action:
		Action.WINDUP:
			_pose_windup(_pose, ease(t, 0.5))
		Action.STRIKE:
			_pose_strike(_pose, t)
		Action.ROLL:
			_roll(t)
		Action.HURT:
			var flinch: float = sin(t * PI)
			_add("Torso", Vector3(-0.5 * flinch, 0.0, 0.12 * flinch))
			_add("Head", Vector3(-0.4 * flinch, 0.0, 0.0))
			_add("ArmR", Vector3(-0.3 * flinch, 0.0, 0.4 * flinch))
			_add("ArmL", Vector3(-0.3 * flinch, 0.0, -0.4 * flinch))
		Action.DRINK:
			var lift: float = sin(t * PI)
			_pose_joint("ArmR", Vector3(1.9 * lift, 0.0, -0.1))
			_pose_joint("ForeR", Vector3(1.9 * lift, 0.0, 0.0))
			_add("Head", Vector3(-0.5 * lift, 0.0, 0.0))
		Action.CHEER:
			var pump: float = sin(_action_time * 7.0)
			_pose_joint("ArmR", Vector3(3.0 + pump * 0.15, 0.0, 0.25))
			_pose_joint("ForeR", Vector3(0.25, 0.0, 0.0))
			if not rig.has_off_hand:
				_pose_joint("ArmL", Vector3(3.0 - pump * 0.15, 0.0, -0.25))
				_pose_joint("ForeL", Vector3(0.25, 0.0, 0.0))
			_add("Head", Vector3(-0.3, 0.0, 0.0))
			rig.position.y = absf(pump) * 0.12
		Action.FLOURISH:
			_pose_flourish(t)


func _pose_windup(pose: StringName, t: float) -> void:
	match pose:
		&"overhead", &"slam":
			_pose_joint("ArmR", Vector3(2.9 * t, 0.0, 0.1))
			_pose_joint("ForeR", Vector3(0.9, 0.0, 0.0))
			_pose_joint("ArmL", Vector3(2.9 * t, 0.0, -0.1))
			_pose_joint("ForeL", Vector3(0.9, 0.0, 0.0))
			_add("Torso", Vector3(-0.4 * t, 0.0, 0.0))
		&"punch":
			_side_arm("Arm", Vector3(0.5, 0.0, 0.35 * t))
			_side_arm("Fore", Vector3(2.1, 0.0, 0.0))
			_add("Torso", Vector3(0.0, 0.55 * t * _side, 0.0))
		&"stab":
			_pose_joint("ArmR", Vector3(0.25, 0.0, 0.3 * t))
			_pose_joint("ForeR", Vector3(1.9, 0.0, 0.0))
			_add("Torso", Vector3(-0.1 * t, 0.35 * t, 0.0))
		&"cast":
			_pose_joint("ArmR", Vector3(1.0 + 1.2 * t, 0.0, 0.2))
			_pose_joint("ForeR", Vector3(1.2 - 0.6 * t, 0.0, 0.0))
			_add("Torso", Vector3(-0.2 * t, 0.2 * t, 0.0))
		&"raise":
			_pose_joint("ArmR", Vector3(2.8 * t, 0.0, 0.35))
			_pose_joint("ForeR", Vector3(0.3, 0.0, 0.0))
			_pose_joint("ArmL", Vector3(2.8 * t, 0.0, -0.35))
			_pose_joint("ForeL", Vector3(0.3, 0.0, 0.0))
		&"guard":
			_pose_joint("ArmL", Vector3(1.35 * t + 0.3, 0.0, -0.2))
			_pose_joint("ForeL", Vector3(1.5, 0.0, 0.0))
			_pose_joint("ArmR", Vector3(1.0 * t, 0.0, 0.2))
			_pose_joint("ForeR", Vector3(1.5, 0.0, 0.0))
			_add("Torso", Vector3(0.2 * t, 0.0, 0.0))
		&"lunge":
			_pose_joint("ArmR", Vector3(0.2, 0.0, 0.5 * t))
			_pose_joint("ForeR", Vector3(1.6, 0.0, 0.0))
			_add("Torso", Vector3(0.35 * t, 0.3 * t, 0.0))
			_add("ThighR", Vector3(-0.5 * t, 0.0, 0.0))
			_add("ThighL", Vector3(0.5 * t, 0.0, 0.0))
		&"spin":
			_pose_joint("ArmR", Vector3(1.5, 0.0, 1.0))
			_pose_joint("ForeR", Vector3(0.2, 0.0, 0.0))
			_pose_joint("ArmL", Vector3(1.5, 0.0, -1.0))
			_pose_joint("ForeL", Vector3(0.2, 0.0, 0.0))
			_add("Torso", Vector3(0.0, 0.8 * t, 0.0))
		_: # &"slash"
			_pose_joint("ArmR", Vector3(2.3 * t, 0.0, 0.2 + 0.7 * t))
			_pose_joint("ForeR", Vector3(0.7, 0.0, 0.0))
			_add("Torso", Vector3(-0.15 * t, 0.65 * t, 0.0))


func _pose_strike(pose: StringName, t: float) -> void:
	var hit: float = 1.0 - t * 0.35 # Snaps out, then starts to settle.
	match pose:
		&"overhead", &"slam":
			_pose_joint("ArmR", Vector3(0.75 * hit, 0.0, 0.05))
			_pose_joint("ForeR", Vector3(0.2, 0.0, 0.0))
			_pose_joint("ArmL", Vector3(0.75 * hit, 0.0, -0.05))
			_pose_joint("ForeL", Vector3(0.2, 0.0, 0.0))
			_add("Torso", Vector3(0.55 * hit, 0.0, 0.0))
			_add("ThighR", Vector3(0.4 * hit, 0.0, 0.0))
			_add("ShinR", Vector3(-0.6 * hit, 0.0, 0.0))
			_add("ThighL", Vector3(-0.3 * hit, 0.0, 0.0))
		&"punch":
			_side_arm("Arm", Vector3(1.55, 0.0, 0.0))
			_side_arm("Fore", Vector3(0.1, 0.0, 0.0))
			_add("Torso", Vector3(0.2, -0.65 * _side * hit, 0.0))
		&"stab", &"lunge":
			_pose_joint("ArmR", Vector3(1.6, 0.0, 0.0))
			_pose_joint("ForeR", Vector3(0.05, 0.0, 0.0))
			_add("Torso", Vector3(0.3 * hit, -0.4 * hit, 0.0))
			_add("ThighR", Vector3(0.6 * hit, 0.0, 0.0))
			_add("ThighL", Vector3(-0.4 * hit, 0.0, 0.0))
		&"cast":
			_pose_joint("ArmR", Vector3(1.6, 0.0, 0.0))
			_pose_joint("ForeR", Vector3(0.05, 0.0, 0.0))
			_add("Torso", Vector3(0.25 * hit, -0.15 * hit, 0.0))
		&"raise":
			_pose_joint("ArmR", Vector3(3.0, 0.0, 0.5))
			_pose_joint("ForeR", Vector3(0.1, 0.0, 0.0))
			_pose_joint("ArmL", Vector3(3.0, 0.0, -0.5))
			_pose_joint("ForeL", Vector3(0.1, 0.0, 0.0))
			_add("Head", Vector3(-0.4, 0.0, 0.0))
		&"guard":
			_pose_windup(&"guard", 1.0)
		&"spin":
			_pose_windup(&"spin", 1.0)
			rig.rotation.y = t * TAU
		_: # &"slash": across the body.
			_pose_joint("ArmR", Vector3(1.1 * hit, 0.0, -0.7))
			_pose_joint("ForeR", Vector3(0.25, 0.0, 0.0))
			_add("Torso", Vector3(0.28 * hit, -0.75 * hit, 0.0))


func _side_arm(joint: String, angles: Vector3) -> void:
	if _side > 0.0:
		_pose_joint(joint + "R", angles)
	else:
		_pose_joint(joint + "L", Vector3(angles.x, angles.y, -angles.z))


## A real forward somersault, tucked, in the dodge's short time.
func _roll(t: float) -> void:
	# Set directly, not eased: easing would unwind the whole turn backward when the roll ends.
	_joints["Hips"].rotation.x = -t * TAU
	rig.position.y = -sin(t * PI) * 0.4 # Hips drop close to the ground, so the tuck stays on the floor.
	for side: String in ["R", "L"]:
		_pose_joint("Thigh" + side, Vector3(1.9, 0.0, 0.0))
		_pose_joint("Shin" + side, Vector3(-2.2, 0.0, 0.0))
		_pose_joint("Arm" + side, Vector3(1.4, 0.0, 0.0))
		_pose_joint("Fore" + side, Vector3(1.6, 0.0, 0.0))
	_add("Torso", Vector3(0.8, 0.0, 0.0))


## Each hero's own idle moment.
func _pose_flourish(t: float) -> void:
	var wave: float = sin(t * PI)
	match rig.style:
		HeroRig.Style.FIGHTER: # Shadow-boxing: a quick one-two.
			var jab_r: float = maxf(sin(t * TAU * 2.0), 0.0)
			var jab_l: float = maxf(-sin(t * TAU * 2.0), 0.0)
			_pose_joint("ArmR", Vector3(0.75 + 0.8 * jab_r, 0.0, 0.22 - 0.2 * jab_r))
			_pose_joint("ForeR", Vector3(1.75 * (1.0 - jab_r) + 0.1, 0.0, 0.0))
			_pose_joint("ArmL", Vector3(0.95 + 0.6 * jab_l, 0.0, -0.22 + 0.2 * jab_l))
			_pose_joint("ForeL", Vector3(1.85 * (1.0 - jab_l) + 0.1, 0.0, 0.0))
			_add("Torso", Vector3(0.0, (jab_l - jab_r) * 0.45, 0.0))
		HeroRig.Style.TANK: # Rolls a stiff shoulder and looks around, on watch.
			_add("Head", Vector3(0.0, sin(t * TAU) * 0.6, 0.0))
			_add("ArmR", Vector3(0.0, 0.0, 0.3 * wave))
			_add("Torso", Vector3(-0.08 * wave, 0.0, 0.05 * wave))
		HeroRig.Style.CASTER: # Lifts a hand to call the orb.
			_pose_joint("ArmR", Vector3(0.5 + 1.8 * wave, 0.0, 0.25))
			_pose_joint("ForeR", Vector3(0.95 - 0.6 * wave, 0.0, 0.0))
			_add("Head", Vector3(-0.2 * wave, 0.0, 0.0))


func _slump() -> void:
	for side: String in ["R", "L"]:
		_pose_joint("Arm" + side, Vector3(-0.2, 0.0, 0.6 if side == "R" else -0.6))
		_pose_joint("Fore" + side, Vector3(0.1, 0.0, 0.0))
		_pose_joint("Thigh" + side, Vector3(0.1, 0.0, 0.0))
		_pose_joint("Shin" + side, Vector3(-0.15, 0.0, 0.0))


# --- Output ----------------------------------------------------------------------------------

func _apply(delta: float) -> void:
	var rate: float = EASE_SNAP if _action == Action.STRIKE or _action == Action.ROLL else EASE_NORMAL
	var blend: float = 1.0 - exp(-rate * delta)
	for joint: String in _joints:
		if joint == "Hips" and _action == Action.ROLL:
			continue
		var node: Node3D = _joints[joint]
		node.rotation = node.rotation.lerp(_target.get(joint, Vector3.ZERO), blend)


## Things that trail behind: the cape, the robe's hem, the orb.
func _secondary(delta: float) -> void:
	if _cape:
		var flutter: float = sin(_life * 3.1) * 0.05
		var flow: float = 0.1 + 0.55 * _walk_amount + flutter
		_cape.rotation.x = lerpf(_cape.rotation.x, flow, 1.0 - exp(-6.0 * delta))
	if _robe:
		_robe.rotation.z = sin(_walk_phase) * 0.06 * _walk_amount
		_robe.rotation.x = 0.1 * _walk_amount
	if _orb:
		_orb.rotation.y += delta * (1.4 + _walk_amount)
		_orb.position.y = 1.35 + sin(_life * 1.8) * 0.12


func _maybe_flourish() -> void:
	if _life < _next_flourish:
		return
	_next_flourish = _life + _rng.randf_range(5.0, 11.0)
	var idle: bool = _action == Action.NONE and _walk_amount < 0.05 and not _dead
	if idle and (player == null or not player.combat_enabled):
		_start(Action.FLOURISH, FLOURISH_TIME)
