class_name InputHints
extends RefCounted
## Turns input actions into on-screen key names, e.g. "interact" -> "E", "attack" -> "Left Click".
## Reads the live InputMap, so rebinding (Phase 6) updates every prompt for free.


static func key_for(action: StringName) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event:
			return key_event.as_text_physical_keycode()
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event:
			return _mouse_button_name(mouse_event.button_index)
	return "?"


static func _mouse_button_name(button: MouseButton) -> String:
	match button:
		MOUSE_BUTTON_LEFT:
			return TranslationServer.translate("KEY_MOUSE_LEFT")
		MOUSE_BUTTON_RIGHT:
			return TranslationServer.translate("KEY_MOUSE_RIGHT")
		MOUSE_BUTTON_MIDDLE:
			return TranslationServer.translate("KEY_MOUSE_MIDDLE")
		_:
			return TranslationServer.translate("KEY_MOUSE_OTHER") % button
