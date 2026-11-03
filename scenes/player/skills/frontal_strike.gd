extends SkillEffect
## A hit (or a quick series of hits) in front of the caster: Shield Bash, Cleave, Haymaker, Flurry.
## The hero's own animation is the attack: each hit makes them strike again, and the effect only
## marks where it lands (an impact, or an arc for wide weapon swings). The scene's Slab is a hidden
## marker for that spot and color; the scene sets the hitbox shape, knockback and these timings.

@export var hits: int = 1
## Seconds between hits when hits > 1. Keep it above enemies' hurtbox hit_cooldown (0.2) or hits get eaten.
@export var hit_interval: float = 0.12
@export var active_time: float = 0.12 ## How long each hit's hitbox is live.
@export var fade_time: float = 0.2
@export var shake: float = 0.25
@export var lunge: float = 0.6 ## How far past the marker the impact lands.
@export var swing: bool = false ## A wide weapon swing: shows an arc instead of an impact.
@export var fx_scale: float = 1.0

var _hits_done: int = 0

@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var slab: MeshInstance3D = $Slab


func _ready() -> void:
	rotation.y = atan2(-direction.x, -direction.z)
	hitbox.damage = damage
	hitbox.element = element
	hitbox.active = false
	slab.visible = false
	for i: int in hits:
		get_tree().create_timer(i * hit_interval + 0.01, false, true).timeout.connect(_hit)
	var last_hit_end: float = (hits - 1) * hit_interval + 0.01 + active_time
	get_tree().create_timer(last_hit_end + fade_time, false, true).timeout.connect(queue_free)


func _hit() -> void:
	hitbox.active = true
	GameFeel.shake(shake)
	_hits_done += 1
	if _hits_done > 1 and caster is Player: # The cast itself already played the first strike.
		(caster as Player).strike_repeated.emit()
	_show_hit()
	get_tree().create_timer(active_time, false, true).timeout.connect(_end_hit)


func _end_hit() -> void:
	hitbox.active = false


func _show_hit() -> void:
	var tint: Color = SkillFx.color_of(element)
	if element == Element.Type.PHYSICAL:
		tint = (slab.get_surface_override_material(0) as StandardMaterial3D).albedo_color
	var forward: Vector3 = Vector3(direction.x, 0.0, direction.z).normalized()
	if swing:
		SkillFx.arc(get_parent(), global_position + Vector3.UP, rotation.y, tint, fx_scale)
		if element != Element.Type.PHYSICAL:
			SkillFx.burst(get_parent(), slab.global_position, element, fx_scale)
	else:
		SkillFx.impact(get_parent(), slab.global_position + forward * lunge * 0.5, rotation.y, element, tint, fx_scale)
