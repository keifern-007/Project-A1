class_name HoarfrostAnimator
extends BossAnimator
## Old Hoarfrost's placeholder poses. Every move has its own silhouette:
## swipe = one arm back over the shoulder; rain = both arms high, then a ground pound;
## breath = head thrown back, then forward; slide = crouch, then flat on its belly.

const ARM_RAISED: float = -2.6
const ARM_FORWARD: float = 1.3
const ARMS_UP: float = -2.9
const BELLY: float = -1.35 ## Radians: lying forward on its belly.

@export var left_arm: Node3D
@export var right_arm: Node3D
@export var head: Node3D


func windup(anim: StringName, duration: float) -> void:
	_restart()
	match anim:
		&"swipe":
			_tween.tween_property(right_arm, "rotation:x", ARM_RAISED, duration * 0.6).set_trans(Tween.TRANS_SINE)
			_tween.parallel().tween_property(visual, "rotation:y", 0.5, duration * 0.6)
		&"rain":
			_tween.tween_property(left_arm, "rotation:x", ARMS_UP, duration * 0.5)
			_tween.parallel().tween_property(right_arm, "rotation:x", ARMS_UP, duration * 0.5)
			_tween.parallel().tween_property(visual, "rotation:x", LEAN * 0.8, duration * 0.5)
		&"breath":
			_tween.tween_property(head, "rotation:x", 0.7, duration * 0.8)
			_tween.parallel().tween_property(visual, "rotation:x", LEAN, duration * 0.8)
		&"slide":
			_tween.tween_property(visual, "scale", Vector3(1.15, 0.8, 1.15), duration * 0.7)
			_tween.parallel().tween_property(visual, "rotation:x", -0.35, duration * 0.7)
		_:
			super.windup(anim, duration)


func strike(anim: StringName) -> void:
	_restart()
	match anim:
		&"swipe":
			_tween.tween_property(right_arm, "rotation:x", ARM_FORWARD, 0.08)
			_tween.parallel().tween_property(visual, "rotation:y", -0.5, 0.1)
		&"rain":
			_tween.tween_property(left_arm, "rotation:x", ARM_FORWARD, 0.1)
			_tween.parallel().tween_property(right_arm, "rotation:x", ARM_FORWARD, 0.1)
			_tween.parallel().tween_property(visual, "rotation:x", -LEAN, 0.1)
		&"breath":
			_tween.tween_property(head, "rotation:x", -0.5, 0.15)
			_tween.parallel().tween_property(visual, "rotation:x", -LEAN * 0.6, 0.15)
		&"slide":
			_tween.tween_property(visual, "scale", Vector3.ONE, 0.1)
			_tween.parallel().tween_property(visual, "rotation:x", BELLY, 0.12)
			_tween.parallel().tween_property(visual, "position:y", -1.0, 0.12)
			_tween.parallel().tween_property(left_arm, "rotation:x", ARMS_UP, 0.12)
			_tween.parallel().tween_property(right_arm, "rotation:x", ARMS_UP, 0.12)
		_:
			super.strike(anim)


func recover(duration: float) -> void:
	super.recover(duration)
	_tween.tween_property(left_arm, "rotation", Vector3.ZERO, duration * 0.6).set_delay(duration * 0.3)
	_tween.tween_property(right_arm, "rotation", Vector3.ZERO, duration * 0.6).set_delay(duration * 0.3)
	_tween.tween_property(head, "rotation", Vector3.ZERO, duration * 0.5)


func roar(duration: float) -> void:
	super.roar(duration)
	_tween.parallel().tween_property(head, "rotation:x", 0.6, duration * 0.3)
	_tween.tween_property(head, "rotation:x", 0.0, duration * 0.2)
