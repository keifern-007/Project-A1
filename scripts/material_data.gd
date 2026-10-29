class_name MaterialData
extends Resource
## A crafting material (herbs, ores, monster parts...), saved as a .tres in resources/materials/.
## Phase 3 crafting turns these into equipment.

@export var id: StringName = &"" ## Save-file key. Never change it once players have saves.
@export var name_key: String = "" ## Translation key, e.g. "MAT_MOONLEAF".
@export var color: Color = Color.WHITE ## Placeholder look until real art exists.
## Gathering track trained by harvesting this from nodes (e.g. &"herbalism"). Empty = not gatherable.
@export var gather_skill: StringName = &""
@export var tier: int = 1 ## Gathering it needs the gather skill at Progression.level_needed(tier).
