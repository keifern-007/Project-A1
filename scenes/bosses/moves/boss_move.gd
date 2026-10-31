class_name BossMove
extends Node3D
## One move of a Boss (child of its "Moves" node). The Boss runs the timeline:
## start() -> windup (telegraph; the boss keeps turning for track_fraction of it) -> strike()
## -> active (active_process() each frame; return true to end early) -> finish() -> recovery (punish window).
## Subclasses decide what the move does: MeleeMove, AreaRainMove, ConeMove, ChargeMove...
## Every move must telegraph by shape or motion (ring, wedge, arrow, pose), never color alone.

@export var anim: StringName = &"swipe" ## Pose the boss's animator plays for this move.
@export var damage: int = 20
@export var knockback: float = 10.0
@export var element: Element.Type = Element.Type.PHYSICAL
@export var shake: float = 0.4 ## Screen shake on strike (GameFeel respects the settings).

@export_group("Timing")
@export var windup: float = 1.0 ## Telegraph time. Phase two shortens every timer.
@export_range(0.0, 1.0) var track_fraction: float = 0.5 ## Part of the windup the boss keeps turning toward you.
@export var active_time: float = 0.15 ## Longest the active part lasts.
@export var recovery: float = 1.0 ## Punish window afterwards.
@export var cooldown: float = 0.0

@export_group("Selection")
@export var min_range: float = 0.0
@export var max_range: float = 4.0
@export var weight: float = 1.0 ## Higher = picked more often when several moves fit.
@export var needs_facing: bool = true ## Only used on targets roughly in front of the boss.
@export var phase_two_only: bool = false

## True while active if the move drives the boss's velocity itself (a charge).
var moves_boss: bool = false
var cooldown_left: float = 0.0


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func is_usable(boss: Boss, distance: float, facing: float) -> bool:
	if cooldown_left > 0.0 or distance < min_range or distance > max_range:
		return false
	if phase_two_only and boss.phase < 2:
		return false
	return not needs_facing or facing > boss.facing_to_attack


## Windup begins. real_windup = seconds it will really take (phase two is faster).
func start(_boss: Boss, _target: Node3D, _real_windup: float) -> void:
	pass


## t goes 0 -> 1 over the windup.
func windup_process(_boss: Boss, _t: float, _delta: float) -> void:
	pass


func strike(_boss: Boss) -> void:
	cooldown_left = cooldown
	GameFeel.shake(shake)


## Called every frame while active. Return true to end the active part now.
func active_process(_boss: Boss, _time: float, _delta: float) -> bool:
	return false


## Called after the boss moved this frame while active (e.g. to notice a wall).
func after_move(_boss: Boss) -> void:
	pass


## The active part ended normally (or the boss crashed): switch hitboxes off, tidy up.
func finish(_boss: Boss) -> void:
	pass


## The boss died mid-move: remove every telegraph and hitbox right away.
func cancel() -> void:
	pass


func _prepare_hitbox(hitbox: HitboxComponent) -> void:
	hitbox.damage = damage
	hitbox.knockback = knockback
	hitbox.element = element
	hitbox.active = false


## Steady fade-in for ground markers (never a strobe).
func _fade_in(marker: GeometryInstance3D, duration: float, alpha_transparency: float = 0.35) -> void:
	marker.visible = true
	marker.transparency = 1.0
	create_tween().tween_property(marker, "transparency", alpha_transparency, maxf(duration * 0.5, 0.05))
