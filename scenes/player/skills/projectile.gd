class_name Projectile
extends SkillEffect
## Flies straight along `direction` and stops at the first enemy or wall it touches.
## The enemy's hurtbox takes the hit from our HitboxComponent. Used by Magic Bolt and Arcane Barrage.

@export var speed: float = 18.0
@export var max_distance: float = 12.0

@export_group("Look")
@export var plain_magic: bool = false ## With no element, still trails sparkles. Takes an element's color if infused.
@export var fx_size: float = 1.0
## Flies as the caster's real main-hand weapon instead of the scene's mesh.
@export var show_weapon: bool = false
@export var spin_speed: float = 0.0 ## Radians per second, end over end. 0 = flies point first.
@export var weapon_leaves_hand_for: float = 0.0 ## Seconds the hero's hand is empty after throwing it.

var _travelled: float = 0.0
var _stopped: bool = false
var _trail: CPUParticles3D
var _spinner: Node3D

@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var sensor: Area3D = $Sensor


func _ready() -> void:
	hitbox.damage = damage
	hitbox.element = element
	direction.y = 0.0
	direction = direction.normalized()
	rotation.y = atan2(-direction.x, -direction.z)
	sensor.body_entered.connect(_on_body_entered)
	_set_up_look()


func _physics_process(delta: float) -> void:
	if _stopped:
		return
	var step: float = speed * delta
	global_position += direction * step
	_travelled += step
	if _spinner and spin_speed != 0.0:
		_spinner.rotation.x -= spin_speed * delta
	if _travelled >= max_distance:
		SkillFx.release_trail(_trail, get_parent())
		queue_free()


# Stop on contact, but stay a couple of physics frames so the enemy's hurtbox sees the hit.
func _on_body_entered(_body: Node3D) -> void:
	if _stopped:
		return
	_stopped = true
	if element != Element.Type.PHYSICAL or plain_magic:
		SkillFx.burst(get_parent(), global_position + Vector3.UP, _fx_kind(), fx_size)
	SkillFx.release_trail(_trail, get_parent())
	_trail = null
	await get_tree().physics_frame
	await get_tree().physics_frame
	queue_free()


func _fx_kind() -> int:
	return SkillFx.ARCANE if element == Element.Type.PHYSICAL else element


func _set_up_look() -> void:
	var mesh: MeshInstance3D = (get_node_or_null("Mesh") if has_node("Mesh") else get_node_or_null("Bolt")) as MeshInstance3D
	if show_weapon and _show_real_weapon() and mesh:
		mesh.visible = false
	if plain_magic and element != Element.Type.PHYSICAL and mesh: # A plain bolt under Ember Infusion.
		var material: StandardMaterial3D = mesh.get_surface_override_material(0).duplicate()
		material.albedo_color = SkillFx.color_of(element)
		mesh.set_surface_override_material(0, material)
	if element != Element.Type.PHYSICAL or plain_magic:
		_trail = SkillFx.make_trail(_fx_kind(), fx_size)
		_trail.position = Vector3.UP
		add_child(_trail)


func _show_real_weapon() -> bool:
	var player: Player = caster as Player
	if player == null:
		return false
	var weapon: ItemData = SaveManager.get_equipped(ItemData.Slot.MAIN_HAND, str(player.character.data.id))
	var scene: PackedScene = weapon.model() if weapon else null
	if scene == null:
		return false
	_spinner = Node3D.new()
	_spinner.position = Vector3.UP
	add_child(_spinner)
	var model: Node3D = scene.instantiate()
	_spinner.add_child(model)
	if spin_speed != 0.0:
		model.position.y = -0.3 # Turns around its middle, not the grip.
	else:
		_spinner.rotation.x = -PI / 2.0 # The blade (+Y) points the way it flies (-Z).
	if weapon_leaves_hand_for > 0.0:
		player.rig.hide_main_hand(weapon_leaves_hand_for)
	return true
