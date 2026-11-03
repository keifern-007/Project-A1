class_name RunSummary
extends RefCounted
## What the game modes add to the results screen and the Mission Board: how far you got and your records.


## Updates the records (saved with the run's rewards) and returns the results line. "" = a normal mission.
## Also applies a won mission's own reward bonus (an Expedition's), before anything is saved.
static func finish(mode: ObjectiveData, run: ModeRun, victory: bool) -> String:
	if victory and mode.victory_reward_multiplier > 1.0:
		GameState.multiply_rewards(mode.victory_reward_multiplier)
		return TranslationServer.translate("UI_EXPEDITION_BONUS") % mode.victory_reward_multiplier
	match mode.type:
		ObjectiveData.Type.ENDLESS_SURVIVAL:
			return _record_line("UI_RESULT_WAVE", "endless_survival_wave", GameState.wave)
		ObjectiveData.Type.ENDLESS_BOSS:
			return _record_line("UI_RESULT_BOSSES", "endless_boss_kills", run.bosses_defeated())
		ObjectiveData.Type.CLASSIC:
			if victory:
				SaveManager.profile["records"]["classic_clears"] += 1
				return TranslationServer.translate("UI_CLASSIC_CLEARS") % SaveManager.profile["records"]["classic_clears"]
			return TranslationServer.translate("UI_RESULT_CLASSIC") % run.progress_text()
	return ""


## "Best: wave 12" for the Mission Board; "" until there's a record to show.
static func best_line(mode: ObjectiveData) -> String:
	var records: Dictionary = SaveManager.profile["records"]
	var key: String = ""
	var text_key: String = ""
	match mode.type:
		ObjectiveData.Type.ENDLESS_SURVIVAL:
			key = "endless_survival_wave"
			text_key = "UI_BEST_WAVE"
		ObjectiveData.Type.ENDLESS_BOSS:
			key = "endless_boss_kills"
			text_key = "UI_BEST_BOSSES"
		ObjectiveData.Type.CLASSIC:
			key = "classic_clears"
			text_key = "UI_CLASSIC_CLEARS"
	if key == "" or records[key] <= 0:
		return ""
	return TranslationServer.translate(text_key) % records[key]


static func title_key(mode: ObjectiveData, victory: bool) -> String:
	if mode.is_endless():
		return "UI_RUN_OVER"
	return "UI_CLASSIC_WON" if victory and mode.type == ObjectiveData.Type.CLASSIC else ""


static func subtitle_key(mode: ObjectiveData, victory: bool) -> String:
	if mode.is_endless():
		return "UI_RUN_OVER_SUB"
	return "UI_CLASSIC_WON_SUB" if victory and mode.type == ObjectiveData.Type.CLASSIC else ""


static func _record_line(text_key: String, record: String, value: int) -> String:
	var records: Dictionary = SaveManager.profile["records"]
	var is_new: bool = value > records[record]
	records[record] = maxi(value, records[record])
	var line: String = TranslationServer.translate(text_key) % [value, records[record]]
	return line + "  " + TranslationServer.translate("UI_NEW_RECORD") if is_new else line
