class_name KingAnimator
extends BossAnimator
## The Sun-Eaten King's placeholder poses:
## smash = scepter raised high, then brought down; beam = arms spread wide, then thrust forward;
## sink = both hands raised to the sky; seal = arms crossed over the chest.

const ARM_UP: float = -2.8
const ARM_FORWARD: float = -1.5
const ARM_DOWN: float = 0.9
const SPREAD: float = 1.3

@export var left_arm: Node3D
@export var right_arm: Node3D


func windup(anim: StringName, duration: float) -> void:
	_restart()
	match anim:
		&"smash":
			_tween.tween_property(right_arm, "rotation:x", ARM_UP, duration * 0.6).set_trans(Tween.TRANS_SINE)
			_tween.parallel().tween_property(visual, "rotation:x", LEAN, duration * 0.6)
		&"beam":
			_tween.tween_property(left_arm, "rotation:z", -SPREAD, duration * 0.6)
			_tween.parallel().tween_property(right_arm, "rotation:z", SPREAD, duration * 0.6)
			_tween.parallel().tween_property(visual, "rotation:x", LEAN, duration * 0.6)
		&"sink", &"seal":
			_tween.tween_property(left_arm, "rotation:x", ARM_UP, duration * 0.5)
			_tween.parallel().tween_property(right_arm, "rotation:x", ARM_UP, duration * 0.5)
		_:
			super.windup(anim, duration)


func strike(anim: StringName) -> void:
	_restart()
	match anim:
		&"smash":
			_tween.tween_property(right_arm, "rotation:x", ARM_DOWN, 0.08)
			_tween.parallel().tween_property(visual, "rotation:x", -LEAN, 0.08)
		&"beam":
			_tween.tween_property(left_arm, "rotation", Vector3(ARM_FORWARD, 0.0, 0.0), 0.12)
			_tween.parallel().tween_property(right_arm, "rotation", Vector3(ARM_FORWARD, 0.0, 0.0), 0.12)
			_tween.parallel().tween_property(visual, "rotation:x", 0.0, 0.12)
		&"sink":
			_tween.tween_property(left_arm, "rotation:x", ARM_DOWN, 0.15)
			_tween.parallel().tween_property(right_arm, "rotation:x", ARM_DOWN, 0.15)
		_:
			super.strike(anim)


func recover(duration: float) -> void:
	super.recover(duration)
	_tween.tween_property(left_arm, "rotation", Vector3.ZERO, duration * 0.6).set_delay(duration * 0.3)
	_tween.tween_property(right_arm, "rotation", Vector3.ZERO, duration * 0.6).set_delay(duration * 0.3)
