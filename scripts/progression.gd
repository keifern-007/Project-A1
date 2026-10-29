class_name Progression
extends RefCounted
## Progression rules: track names, the Rank XP curve, XP amounts and skill points.
## A track key is "<kind>/<category>", e.g. "gathering/herbalism", "crafting/axe", "mastery/dagger".
## Every activity (gathering, crafting, fighting) earns Rank XP. Each Rank level-up gives skill
## points, which you spend at the Skill Shrine to raise whichever track you choose.

const GATHERING: String = "gathering"
const CRAFTING: String = "crafting"
const MASTERY: String = "mastery"
const KINDS: Array[String] = [GATHERING, CRAFTING, MASTERY]

const MAX_LEVEL: int = 100 ## For Rank and for every track.
## Rank XP to go from level L to L+1 = base + growth * (L - 1).
const RANK_CURVE: Vector2i = Vector2i(100, 50)
const SKILL_POINTS_PER_RANK: int = 3
const TRACK_LEVEL_COST: int = 1 ## Skill points per track level.

const GATHER_XP_PER_ITEM: int = 5
const CRAFT_XP_PER_TIER: int = 25
## Track level needed to gather / craft / use something of a tier. Index = tier.
## Tune here: T1 always, T2 at level 3, T3 at level 6.
const TIER_LEVELS: Array[int] = [1, 1, 3, 6]

## Mastery with nothing in the main hand.
const UNARMED_CATEGORY: StringName = &"fists"


static func level_needed(tier: int) -> int:
	return TIER_LEVELS[clampi(tier, 0, TIER_LEVELS.size() - 1)]


## "Axe Crafting 3" — for locked-item hints.
static func requirement_text(kind: String, category: StringName, tier: int) -> String:
	return "%s %d" % [display_name(track_key(kind, category)), level_needed(tier)]


static func track_key(kind: String, category: StringName) -> String:
	return "%s/%s" % [kind, category]


static func kind_of(key: String) -> String:
	return key.get_slice("/", 0)


static func category_of(key: String) -> String:
	return key.get_slice("/", 1)


## "Herbalism", "Axe Crafting", "Dagger Mastery".
static func display_name(key: String) -> String:
	var category: String = tr_static("CATEGORY_" + category_of(key).to_upper())
	return tr_static("UI_TRACK_" + kind_of(key).to_upper()) % category


static func xp_to_next(level: int, curve: Vector2i = RANK_CURVE) -> int:
	return curve.x + curve.y * (level - 1)


static func level_for_xp(xp: int, curve: Vector2i = RANK_CURVE) -> int:
	var level: int = 1
	while level < MAX_LEVEL and xp >= xp_to_next(level, curve):
		xp -= xp_to_next(level, curve)
		level += 1
	return level


## [xp into the current Rank level, xp needed for the next one].
static func progress(xp: int) -> Vector2i:
	var level: int = 1
	while level < MAX_LEVEL and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
	return Vector2i(xp, xp_to_next(level))


## The next tier a track level would unlock (level 2 -> T2, needs level 3). 0 if none left.
static func next_tier(level: int) -> int:
	for tier: int in range(1, TIER_LEVELS.size()):
		if TIER_LEVELS[tier] > level:
			return tier
	return 0


## Every track the current content can train, so the Shrine can list them even at 0 XP.
static func all_track_keys() -> Array[String]:
	var keys: Array[String] = []
	for material: MaterialData in MaterialRegistry.all():
		if material.gather_skill != &"":
			_add_unique(keys, track_key(GATHERING, material.gather_skill))
	for item: ItemData in ItemRegistry.all():
		_add_unique(keys, track_key(CRAFTING, item.category))
		if trains_mastery(item):
			_add_unique(keys, track_key(MASTERY, item.category))
	_add_unique(keys, track_key(MASTERY, UNARMED_CATEGORY))
	return keys


## Trinkets and consumables don't have a mastery; weapons and armor do.
static func trains_mastery(item: ItemData) -> bool:
	return item.slot != ItemData.Slot.TRINKET and item.slot != ItemData.Slot.CONSUMABLE


static func tr_static(key: String) -> String:
	return TranslationServer.translate(key)


static func _add_unique(keys: Array[String], key: String) -> void:
	if not keys.has(key):
		keys.append(key)
