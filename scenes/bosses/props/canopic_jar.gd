class_name CanopicJar
extends StaticBody3D
## Holds the Sun-Eaten King's seal: break all of them to open his sarcophagus.
## An object, not an enemy (no kill credit, no loot), so the fight stays a duel.
## Every pulse_interval it sends out a shockwave: a DropZone ring that fills, then hits around it.

signal broken

@export var max_health: int = 60
@export var pulse_zone_scene: PackedScene
@export var pulse_radius: float = 3.5
@export var pulse_telegraph: float = 1.2
@export var pulse_interval: float = 4.0
@export var pulse_damage: int = 12
@export var pulse_knockback: float = 9.0

var first_pulse_delay: float = 1.5 ## Set by the King so the jars don't all pulse together.

var _pulse_left: float = 0.0
var _broken: bool = false

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var visual: Node3D = $Visual
@onready var hint: Label3D = $Hint


func _ready() -> void:
	health.set_max_health(max_health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	hint.text = tr("HINT_BREAK_JAR")
	_pulse_left = first_pulse_delay
	visual.scale = Vector3(1.0, 0.05, 1.0)
	create_tween().tween_property(visual, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if _broken:
		return
	_pulse_left -= delta
	if _pulse_left <= 0.0:
		_pulse_left = pulse_interval
		_pulse()


func _pulse() -> void:
	if pulse_zone_scene == null:
		return
	var zone: DropZone = pulse_zone_scene.instantiate()
	zone.setup(Vector3(global_position.x, 0.0, global_position.z), pulse_radius, pulse_telegraph,
		pulse_damage, Element.Type.PHYSICAL, pulse_knockback, null, 0.0)
	zone.show_falling = false
	get_parent().add_child(zone)


func _on_damaged(_amount: int) -> void:
	visual.scale = Vector3(1.15, 0.85, 1.15)
	create_tween().tween_property(visual, "scale", Vector3.ONE, 0.12)


func _on_died() -> void:
	_broken = true
	hurtbox.set_deferred("monitoring", false)
	$CollisionShape3D.set_deferred("disabled", true)
	hint.visible = false
	GameFeel.shake(0.3)
	broken.emit()
	var shatter: Tween = create_tween().set_parallel()
	shatter.tween_property(visual, "scale", Vector3(1.6, 0.05, 1.6), 0.25)
	shatter.chain().tween_callback(queue_free)
