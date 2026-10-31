class_name MeleeMove
extends BossMove
## A close-range hit in front of the boss (swipe, smash). Children: HitboxComponent and Marker
## (a flat mesh with the hitbox's footprint that fades in during the windup).

@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var marker: GeometryInstance3D = $Marker


func _ready() -> void:
	_prepare_hitbox(hitbox)
	marker.visible = false


func start(_boss: Boss, _target: Node3D, real_windup: float) -> void:
	_fade_in(marker, real_windup)


func strike(boss: Boss) -> void:
	super.strike(boss)
	marker.visible = false
	hitbox.active = true


func finish(_boss: Boss) -> void:
	hitbox.active = false


func cancel() -> void:
	marker.visible = false
	hitbox.active = false
