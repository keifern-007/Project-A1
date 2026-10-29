class_name GameFeel
extends RefCounted
## The single place for "juice" that affects the whole screen: hit stop and screen shake.
## Everything here respects the accessibility settings, so call these instead of doing it by hand.

const HIT_STOP_TIME_SCALE: float = 0.05
const REDUCED_FLASHING_SHAKE: float = 0.3 ## Shake multiplier when reduce_flashing is on.

static var _hit_stop_token: int = 0


## Briefly slows time to near-zero so hits feel heavy. Overlapping calls just extend it.
static func hit_stop(tree: SceneTree, duration: float) -> void:
	if duration <= 0.0:
		return
	Engine.time_scale = HIT_STOP_TIME_SCALE
	_hit_stop_token += 1
	var token: int = _hit_stop_token
	# ignore_time_scale = true, otherwise the timer itself would be slowed down.
	tree.create_timer(duration, true, false, true).timeout.connect(func() -> void:
		if token == _hit_stop_token:
			Engine.time_scale = 1.0)


static func cancel_hit_stop() -> void:
	_hit_stop_token += 1
	Engine.time_scale = 1.0


## trauma: roughly 0.1 (tiny bump) to 1.0 (huge hit). The camera listens on EventBus.
static func shake(trauma: float) -> void:
	var amount: float = trauma * Settings.screen_shake
	if Settings.reduce_flashing:
		amount *= REDUCED_FLASHING_SHAKE
	if amount > 0.0:
		EventBus.screen_shake_requested.emit(amount)
