extends Node
## Options + accessibility flags, persisted to user://settings.cfg.

const SETTINGS_PATH: String = "user://settings.cfg"

enum ColorblindMode { OFF, PROTANOPIA, DEUTERANOPIA, TRITANOPIA }

var locale: String = "en"
var reduce_flashing: bool = false
var screen_shake: float = 1.0 ## 0 = off, 1 = full.
var arachnophobia_mode: bool = false
var colorblind_mode: ColorblindMode = ColorblindMode.OFF


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		locale = cfg.get_value("general", "locale", locale)
		reduce_flashing = cfg.get_value("accessibility", "reduce_flashing", reduce_flashing)
		screen_shake = cfg.get_value("accessibility", "screen_shake", screen_shake)
		arachnophobia_mode = cfg.get_value("accessibility", "arachnophobia_mode", arachnophobia_mode)
		colorblind_mode = cfg.get_value("accessibility", "colorblind_mode", colorblind_mode)
	TranslationServer.set_locale(locale)


func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("general", "locale", locale)
	cfg.set_value("accessibility", "reduce_flashing", reduce_flashing)
	cfg.set_value("accessibility", "screen_shake", screen_shake)
	cfg.set_value("accessibility", "arachnophobia_mode", arachnophobia_mode)
	cfg.set_value("accessibility", "colorblind_mode", colorblind_mode)
	cfg.save(SETTINGS_PATH)
	TranslationServer.set_locale(locale)
	EventBus.settings_changed.emit()
