class_name ObjectiveTag
## The Mission Board's objective types: their order on the board and a colored tag naming each one.
## The tag always carries the type's name, so the color is only a help, never the only cue.

## Board order. Objectives are listed grouped by type, in this order.
const ORDER: Array[ObjectiveData.Type] = [
	ObjectiveData.Type.HORDE, ObjectiveData.Type.GATHER, ObjectiveData.Type.BOSS,
	ObjectiveData.Type.EXPEDITION, ObjectiveData.Type.HUNT,
	ObjectiveData.Type.ENDLESS_SURVIVAL, ObjectiveData.Type.ENDLESS_BOSS, ObjectiveData.Type.CLASSIC,
]
const TAG_SIZE: Vector2 = Vector2(104, 38)
const FONT_SIZE: int = 15


## Where this type sits in ORDER (types not listed go last).
static func rank_of(objective: ObjectiveData) -> int:
	var index: int = ORDER.find(objective.type)
	return index if index >= 0 else ORDER.size()


## The same objectives, listed type by type (ORDER), keeping their order within a type.
static func grouped(entries: Array[ObjectiveData]) -> Array[ObjectiveData]:
	var result: Array[ObjectiveData] = []
	for rank: int in ORDER.size() + 1:
		for entry: ObjectiveData in entries:
			if rank_of(entry) == rank:
				result.append(entry)
	return result


static func text_key(type: ObjectiveData.Type) -> String:
	match type:
		ObjectiveData.Type.HORDE: return "UI_TAG_HORDE"
		ObjectiveData.Type.GATHER: return "UI_TAG_GATHER"
		ObjectiveData.Type.BOSS: return "UI_TAG_BOSS"
		ObjectiveData.Type.EXPEDITION: return "UI_TAG_EXPEDITION"
		ObjectiveData.Type.HUNT: return "UI_TAG_HUNT"
		ObjectiveData.Type.ENDLESS_SURVIVAL, ObjectiveData.Type.ENDLESS_BOSS: return "UI_TAG_ENDLESS"
		ObjectiveData.Type.CLASSIC: return "UI_TAG_CLASSIC"
	return "UI_TAG_OTHER"


static func color(type: ObjectiveData.Type) -> Color:
	match type:
		ObjectiveData.Type.HORDE: return Color(0.72, 0.24, 0.2)
		ObjectiveData.Type.GATHER: return Color(0.26, 0.56, 0.28)
		ObjectiveData.Type.BOSS: return Color(0.48, 0.28, 0.68)
		ObjectiveData.Type.EXPEDITION: return Color(0.16, 0.5, 0.58)
		ObjectiveData.Type.HUNT: return Color(0.6, 0.36, 0.16)
		ObjectiveData.Type.ENDLESS_SURVIVAL, ObjectiveData.Type.ENDLESS_BOSS: return Color(0.78, 0.46, 0.12)
		ObjectiveData.Type.CLASSIC: return Color(0.62, 0.54, 0.16)
	return Color(0.35, 0.35, 0.4)


## The tag itself: a colored box with the type's name in it.
static func make(type: ObjectiveData.Type) -> PanelContainer:
	var tag: PanelContainer = PanelContainer.new()
	tag.custom_minimum_size = TAG_SIZE
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color(type)
	box.set_corner_radius_all(4)
	tag.add_theme_stylebox_override("panel", box)
	var label: Label = Label.new()
	label.text = text_key(type)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("outline_size", 3)
	tag.add_child(label)
	return tag
