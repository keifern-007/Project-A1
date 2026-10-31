class_name Enemy
extends CharacterBody3D
## What every regular enemy shares: stats from EnemyData (+ biome variant and look), health,
## statuses, knockback, hit/death feel, despawning and target helpers.
## A new enemy type extends this and only writes its behaviour in _behave() (see MeleeEnemy).
## Its scene needs: StatsComponent, HealthComponent, HurtboxComponent (status set),
## StatusEffectComponent, Visual (Node3D) and CollisionShape3D.
## Arachnids (data.is_arachnid) put their spider model under Visual/Arachnid and a non-spider one
## under Visual/Alternate; arachnophobia mode shows the Alternate instead.

const KNOCKBACK_DECAY: float = 30.0 ## Speed lost per second while being pushed.
const HIT_STOP: float = 0.04
const KILL_HIT_STOP: float = 0.08
const KILL_SHAKE: float = 0.15
const LEAN_BACK: float = 0.436 ## ~25 degrees, in radians. The usual wind-up telegraph.
const LEAN_FORWARD: float = -0.262 ## ~-15 degrees. The strike.

@export var data: EnemyData
## Chase from any distance (set by spawners). Otherwise waits for detection_range.
@export var hunt_from_start: bool = false
## Scales max HP from data (set by spawners for later waves).
@export var health_multiplier: float = 1.0

var target: Node3D = null
var dead: bool = false

var _ward_left: float = 0.0
var _ward_bubble: MeshInstance3D
var _ward_label: Label3D

var _knockback: Vector3 = Vector3.ZERO
var _tween: Tween
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var stats: StatsComponent = $StatsComponent
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var status: StatusEffectComponent = $StatusEffectComponent
@onready var visual: Node3D = $Visual
@onready var body_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group("enemies") # Supports (Goblin Shaman) look for allies here.
	if data:
		data = data.variant_for(GameState.biome())
		data.apply_look(visual)
		_apply_arachnophobia()
		if data.is_arachnid: # The option can change mid-run, from the pause menu.
			EventBus.settings_changed.connect(_apply_arachnophobia)
	status.data = data
	if data:
		stats.max_health = data.max_health
		stats.attack_power = data.attack_power
		stats.defense = data.defense
		health.set_max_health(roundi(data.max_health * health_multiplier * GameState.enemy_health_multiplier()))
	health.damaged.connect(_on_damaged)
	hurtbox.hurt.connect(_on_hurt)
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if _ward_left > 0.0:
		_ward_left -= delta
		if _ward_left <= 0.0:
			_end_ward()
	if status.is_frozen():
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		_behave(delta)
	# Knockback overrides whatever the behaviour wanted to do this frame.
	if _knockback != Vector3.ZERO:
		velocity.x = _knockback.x
		velocity.z = _knockback.z
		_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()
	_after_move()


## Spider models are swapped for their alternate when the player turned on arachnophobia mode.
func _apply_arachnophobia() -> void:
	var spider: Node3D = visual.get_node_or_null("Arachnid")
	var alternate: Node3D = visual.get_node_or_null("Alternate")
	if spider == null or alternate == null:
		return
	var swap: bool = data.is_arachnid and Settings.arachnophobia_mode
	spider.visible = not swap
	alternate.visible = swap


## Override: set velocity.x/z, face, attack. Not called while frozen or dead.
func _behave(_delta: float) -> void:
	pass


## Override: react to what the move hit (is_on_wall() etc.). Called every frame while alive.
func _after_move() -> void:
	pass


## Override: switch off hitboxes and anything else that could still hurt after death/despawn.
func _stop_attacking() -> void:
	pass


## Walk speed after statuses (Chill).
func current_speed() -> float:
	return data.move_speed * status.speed_multiplier()


## Moves along the ground toward `dir` at current_speed() and faces it.
func walk(dir: Vector3, speed_factor: float = 1.0) -> void:
	velocity.x = dir.x * current_speed() * speed_factor
	velocity.z = dir.z * current_speed() * speed_factor
	if dir != Vector3.ZERO:
		face(dir)


func stand_still() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func face(dir: Vector3) -> void:
	visual.rotation.y = atan2(-dir.x, -dir.z)


func find_nearest_player() -> Node3D:
	return Targeting.nearest_player(self)


func is_target_valid() -> bool:
	return Targeting.is_alive(target)


## Keeps `target` pointing at a living player. Returns false if there is none.
func refresh_target() -> bool:
	if not is_target_valid():
		target = find_nearest_player()
	return target != null


func flat_distance_to(node: Node3D) -> float:
	var offset: Vector3 = node.global_position - global_position
	offset.y = 0.0
	return offset.length()


func flat_direction_to(node: Node3D) -> Vector3:
	var offset: Vector3 = node.global_position - global_position
	offset.y = 0.0
	return offset.normalized()


## Leaning is the telegraph: shape/motion, not color, so it reads for everyone.
func animate_lean(angle: float, duration: float) -> void:
	restart_tween()
	_tween.tween_property(visual, "rotation:x", angle, duration)


## Stops the current body animation (lean, sway) without starting a new one.
func stop_tween() -> void:
	if _tween:
		_tween.kill()


func restart_tween() -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	return _tween


func _on_hurt(_amount: int, hitbox: HitboxComponent) -> void:
	var away: Vector3 = global_position - hitbox.global_position
	away.y = 0.0
	var resistance: float = data.knockback_resistance if data else 0.0
	_knockback = away.normalized() * hitbox.knockback * (1.0 - resistance)
	GameFeel.hit_stop(get_tree(), HIT_STOP)


func _on_damaged(_amount: int) -> void:
	if dead:
		return
	visual.scale = Vector3(1.2, 0.8, 1.2)
	create_tween().tween_property(visual, "scale", Vector3.ONE, 0.12)


## Removed without dying (no kill credit), e.g. to clear the arena for a boss.
func despawn() -> void:
	if dead:
		return
	_shut_down()
	status.clear()
	restart_tween().tween_property(visual, "scale", Vector3(0.05, 0.05, 0.05), 0.3)
	_tween.tween_callback(queue_free)


func _on_died() -> void:
	_shut_down()
	velocity = Vector3.ZERO
	EventBus.enemy_killed.emit(self)
	GameFeel.hit_stop(get_tree(), KILL_HIT_STOP)
	GameFeel.shake(KILL_SHAKE)
	restart_tween().tween_property(visual, "scale", Vector3(1.4, 0.05, 1.4), 0.25)
	_tween.tween_callback(queue_free)


## A support's ward: takes `multiplier` × damage for `duration` seconds. Shown by a bubble and
## '+ Warded' text (shape + words, never color alone). Damage over time still gets through.
func apply_ward(duration: float, multiplier: float) -> void:
	if dead:
		return
	_ward_left = duration
	hurtbox.damage_taken_multiplier = multiplier
	if _ward_bubble == null:
		_build_ward_visuals()
	_ward_bubble.visible = true
	_ward_label.visible = true
	_ward_bubble.scale = Vector3.ONE * 0.3
	create_tween().tween_property(_ward_bubble, "scale", Vector3.ONE, 0.2)


func is_warded() -> bool:
	return _ward_left > 0.0


func _end_ward() -> void:
	_ward_left = 0.0
	hurtbox.damage_taken_multiplier = 1.0
	if _ward_bubble:
		_ward_bubble.visible = false
		_ward_label.visible = false


func _build_ward_visuals() -> void:
	var radius: float = 0.8
	var center_y: float = 0.7
	var shape: Shape3D = body_shape.shape
	if shape is CapsuleShape3D:
		radius = maxf((shape as CapsuleShape3D).radius, (shape as CapsuleShape3D).height * 0.5)
	elif shape is CylinderShape3D:
		radius = maxf((shape as CylinderShape3D).radius, (shape as CylinderShape3D).height * 0.5)
	center_y = body_shape.position.y
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.9, 0.5, 0.3)
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius + 0.25
	sphere.height = (radius + 0.25) * 2.0
	sphere.material = material
	_ward_bubble = MeshInstance3D.new()
	_ward_bubble.mesh = sphere
	_ward_bubble.position.y = center_y
	add_child(_ward_bubble)
	_ward_label = Label3D.new()
	_ward_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_ward_label.text = tr("STATUS_WARDED")
	_ward_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_ward_label.no_depth_test = true
	_ward_label.pixel_size = 0.015
	_ward_label.font_size = 24
	_ward_label.outline_size = 8
	_ward_label.position.y = status.label_height + 0.5
	add_child(_ward_label)


func _shut_down() -> void:
	_end_ward()
	dead = true
	body_shape.set_deferred("disabled", true)
	hurtbox.set_deferred("monitoring", false)
	_stop_attacking()
