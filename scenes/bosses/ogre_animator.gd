class_name OgreAnimator
extends Node
## All of the Ogre's placeholder "animations", done with tweens on its Visual and club arm.
## When real models arrive, swap this for an AnimationPlayer — the boss only calls these methods.

const ARM_RAISED: float = -2.4 ## Club up and back over the head.
const ARM_SLAMMED: float = 1.2 ## Club driven down in front.
const ARM_SIDE: float = 1.4 ## Club held out sideways for the sweep.
const TWIST: float = 1.0
const LEAN: float = 0.2

@export var visual: Node3D
@export var arm: Node3D

var _tween: Tween


func roar(duration: float) -> void:
	_restart()
	_tween.tween_property(visual, "rotation:x", LEAN * 1.5, duration * 0.3)
	_tween.parallel().tween_property(arm, "rotation:x", ARM_RAISED, duration * 0.3)
	_tween.tween_interval(duration * 0.4)
	_tween.tween_property(visual, "rotation:x", 0.0, duration * 0.3)
	_tween.parallel().tween_property(arm, "rotation:x", 0.0, duration * 0.3)


func windup(pose: BossAttack.Pose, duration: float) -> void:
	_restart()
	match pose:
		BossAttack.Pose.OVERHEAD:
			# Reaches the top early, then HOLDS: the delayed swing that punishes panic-dodging.
			_tween.tween_property(arm, "rotation:x", ARM_RAISED, duration * 0.6).set_trans(Tween.TRANS_SINE)
			_tween.parallel().tween_property(visual, "rotation:x", LEAN, duration * 0.6)
		BossAttack.Pose.SWEEP:
			_tween.tween_property(arm, "rotation:z", ARM_SIDE, duration * 0.5)
			_tween.parallel().tween_property(visual, "rotation:y", TWIST, duration * 0.8)
		BossAttack.Pose.LEAP:
			_tween.tween_property(visual, "scale", Vector3(1.2, 0.75, 1.2), duration * 0.6)
			_tween.tween_property(visual, "scale", Vector3(0.9, 1.2, 0.9), duration * 0.15)


func strike(pose: BossAttack.Pose) -> void:
	_restart()
	match pose:
		BossAttack.Pose.OVERHEAD:
			_tween.tween_property(arm, "rotation:x", ARM_SLAMMED, 0.08)
			_tween.parallel().tween_property(visual, "rotation:x", -LEAN, 0.08)
		BossAttack.Pose.SWEEP:
			_tween.tween_property(visual, "rotation:y", -TWIST, 0.12)
		BossAttack.Pose.LEAP:
			_tween.tween_property(visual, "scale", Vector3(1.3, 0.7, 1.3), 0.06)


func recover(duration: float) -> void:
	_restart()
	_tween.set_parallel(true)
	_tween.tween_property(arm, "rotation", Vector3.ZERO, duration * 0.6).set_delay(duration * 0.3)
	_tween.tween_property(visual, "rotation", Vector3.ZERO, duration * 0.6).set_delay(duration * 0.3)
	_tween.tween_property(visual, "scale", Vector3.ONE, duration * 0.4)


func die() -> void:
	_restart()
	_tween.set_parallel(true)
	_tween.tween_property(visual, "scale", Vector3.ONE, 0.2)
	_tween.tween_property(arm, "rotation", Vector3(ARM_SLAMMED, 0.0, 0.0), 0.6)
	_tween.tween_property(visual, "rotation", Vector3(-PI / 2.0, 0.0, 0.0), 1.4) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _restart() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
