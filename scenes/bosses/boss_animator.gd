class_name BossAnimator
extends Node
## A Boss's placeholder "animations" (tweens on its Visual). The Boss only calls these methods,
## so real models can swap in an AnimationPlayer later. Override windup()/strike() per boss;
## the defaults are a generic lean back -> lunge, readable for any move.

const LEAN: float = 0.25

@export var visual: Node3D

var _tween: Tween


func roar(duration: float) -> void:
	_restart()
	_tween.tween_property(visual, "rotation:x", LEAN * 1.5, duration * 0.3)
	_tween.tween_interval(duration * 0.4)
	_tween.tween_property(visual, "rotation:x", 0.0, duration * 0.3)


func windup(_anim: StringName, duration: float) -> void:
	_restart()
	_tween.tween_property(visual, "rotation:x", LEAN, duration * 0.7)


func strike(_anim: StringName) -> void:
	_restart()
	_tween.tween_property(visual, "rotation:x", -LEAN, 0.08)


func recover(duration: float) -> void:
	_restart()
	_tween.set_parallel(true)
	_tween.tween_property(visual, "rotation", Vector3.ZERO, duration * 0.6).set_delay(duration * 0.3)
	_tween.tween_property(visual, "scale", Vector3.ONE, duration * 0.4)
	_tween.tween_property(visual, "position", Vector3.ZERO, duration * 0.5)


func die() -> void:
	_restart()
	_tween.set_parallel(true)
	_tween.tween_property(visual, "scale", Vector3.ONE, 0.2)
	_tween.tween_property(visual, "position", Vector3.ZERO, 0.2)
	_tween.tween_property(visual, "rotation", Vector3(-PI / 2.0, 0.0, 0.0), 1.4) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _restart() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
