class_name InputHints
extends RefCounted
## Turns input actions into on-screen key names, e.g. "interact" -> "E".
## Reads the live InputMap, so rebinding (Phase 6) updates every prompt for free.


static func key_for(action: StringName) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event:
			return key_event.as_text_physical_keycode()
	return "?"
