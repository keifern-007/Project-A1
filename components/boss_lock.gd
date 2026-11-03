class_name BossLock
extends Node
## Lock-on for the over-the-shoulder camera: CameraFollow keeps the boss in view and aims at it while
## this is active. On by default when a boss appears; the lock_on action turns it off and on.
## Lets go while the boss can't be hurt (the Sun-Eaten King's seal), so you can aim at the jars.

const MARKER_TEXT: String = "[ + ]" ## A shape, so the lock never relies on color.
const MARKER_PIXEL_SIZE: float = 0.0025

var wanted: bool = true ## The player's choice; lasts the whole run.

var _boss: Node3D = null
var _boss_hurtbox: HurtboxComponent = null
var _boss_center: Node3D = null ## Its body shape: the point to look at, whatever the boss's size.
var _active: bool = false
var _available: bool = false
var _marker: Label3D


func _ready() -> void:
	_marker = Label3D.new()
	_marker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_marker.text = MARKER_TEXT
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.fixed_size = true
	_marker.pixel_size = MARKER_PIXEL_SIZE
	_marker.top_level = true
	_marker.visible = false
	add_child(_marker)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_defeated.connect(func(_defeated: Node) -> void: _boss = null)


func is_active() -> bool:
	return _active


## Where to look and aim. Only meaningful while is_active().
func point() -> Vector3:
	return _boss_center.global_position


## Called every frame. `can_lock` = over the shoulder and actually playing (not paused, dead or in a menu).
func update(can_lock: bool) -> void:
	# Also lets go while a hunted boss limps away, rather than swinging the camera across the map.
	var fleeing: bool = is_instance_valid(_boss) and _boss.has_method("is_fleeing") and _boss.call("is_fleeing")
	var lockable: bool = can_lock and is_instance_valid(_boss) and not _boss_hurtbox.invulnerable and not fleeing
	if lockable and Input.is_action_just_pressed("lock_on"):
		wanted = not wanted
	var active: bool = lockable and wanted
	if active != _active or lockable != _available:
		_active = active
		_available = lockable
		EventBus.camera_lock_changed.emit(_available, _active)
	_marker.visible = _active
	if _active:
		_marker.global_position = point()


func _on_boss_spawned(boss: Node) -> void:
	_boss = boss as Node3D
	_boss_hurtbox = boss.get("hurtbox") as HurtboxComponent
	_boss_center = boss.get_node("CollisionShape3D") as Node3D
