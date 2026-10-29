extends Node
## Meta-progression: everything that survives between runs (materials, crafted items, the chosen
## character and each character's loadout, Rank XP, skill points and track levels, currency, unlocks,
## stats). Saved as JSON at user://save.json, versioned so old saves can be migrated.
## Shared account: everything is shared between characters except the loadout and talents (team decision).

const SAVE_PATH: String = "user://save.json"
const TEMP_PATH: String = "user://save.json.tmp"
const SAVE_VERSION: int = 6 ## v2: 8-slot loadout. v3: items are counted. v4: tracks bought with skill points.
## v5: characters, one loadout each. v6: talent trees per character.
## v3 tracks levelled from their own XP with this curve; only used to migrate old saves.
const V3_TRACK_CURVE: Vector2i = Vector2i(30, 20)
## Share of a run's rewards kept when the run is LOST. Design decision: keep everything (1.0).
## 0.5 = keep half, 0.0 = lose it all.
const DEFEAT_KEEP_FRACTION: float = 1.0

var profile: Dictionary = {}


func _ready() -> void:
	load_profile()


func new_profile() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"currency": 0,
		"materials": {},
		"items": {},
		"character": "", # Chosen character id; "" = not chosen yet (the first one is used).
		"loadouts": {}, # character id -> { slot key: item id or "" }
		"talents": {}, # character id -> [talent id, ...]
		"unlocks": [],
		"skill_points": 0,
		"track_levels": {}, # track key -> level; missing = level 1.
		"rank_xp": 0,
		"stats": { "runs_played": 0, "runs_won": 0 },
	}


func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		profile = new_profile()
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		profile = _migrate(data)
		return
	# Never silently overwrite a broken save: set it aside so it can be inspected or recovered.
	var backup: String = "user://save.corrupt.%d.json" % int(Time.get_unix_time_from_system())
	DirAccess.rename_absolute(SAVE_PATH, backup)
	push_warning("SaveManager: save file was unreadable, moved to %s. Starting a new profile." % backup)
	profile = new_profile()


func save_profile() -> void:
	profile["version"] = SAVE_VERSION
	# Write a temp file, then swap it in: a crash mid-write can't destroy the existing save.
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: can't write %s (%s)" % [TEMP_PATH, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(profile, "\t"))
	file.close()
	var err: Error = DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("SaveManager: can't replace %s (%s)" % [SAVE_PATH, error_string(err)])


## Adds a finished run's rewards (materials + XP) to the profile and saves. Call once per run.
## Every track's XP feeds Rank. Returns the Rank-ups: [{ "level": n, "points": skill points }, ...].
func commit_run(run_rewards: Dictionary, victory: bool) -> Array[Dictionary]:
	var keep: float = 1.0 if victory else DEFEAT_KEEP_FRACTION
	var materials: Dictionary = run_rewards.get("materials", {})
	for id: Variant in materials:
		add_material(str(id), floori(materials[id] * keep))
	var level_ups: Array[Dictionary] = []
	var xp: Dictionary = run_rewards.get("xp", {})
	for track: Variant in xp:
		level_ups.append_array(add_rank_xp(floori(xp[track] * keep)))
	var stats: Dictionary = profile["stats"]
	stats["runs_played"] += 1
	if victory:
		stats["runs_won"] += 1
	save_profile()
	return level_ups


# --- Materials -------------------------------------------------------------------------------

func add_material(id: String, amount: int) -> void:
	if amount <= 0:
		return
	profile["materials"][id] = get_material_count(id) + amount


func get_material_count(id: String) -> int:
	return int(profile["materials"].get(id, 0))


# --- Crafting --------------------------------------------------------------------------------

func get_item_count(id: String) -> int:
	return int(profile["items"].get(id, 0))


func has_item(id: String) -> bool:
	return get_item_count(id) > 0


## True if the track for `kind` is high enough for this tier (see Progression.TIER_LEVELS).
func meets_tier(kind: String, category: StringName, tier: int) -> bool:
	return get_track_level(Progression.track_key(kind, category)) >= Progression.level_needed(tier)


func can_craft_tier(item: ItemData) -> bool:
	return meets_tier(Progression.CRAFTING, item.category, item.tier)


## Weapons and armor need mastery for their tier; trinkets/consumables have no mastery.
func can_use_tier(item: ItemData) -> bool:
	return not Progression.trains_mastery(item) or meets_tier(Progression.MASTERY, item.category, item.tier)


## Craft as many copies as you like (crafting XP grows by doing it again and again).
func can_craft(item: ItemData) -> bool:
	if not can_craft_tier(item):
		return false
	for cost: MaterialCost in item.cost:
		if get_material_count(str(cost.material.id)) < cost.amount:
			return false
	return true


## Spends the materials, adds the item, saves. Returns false (and changes nothing) if not allowed.
func craft(item: ItemData) -> bool:
	if not can_craft(item):
		return false
	for cost: MaterialCost in item.cost:
		var id: String = str(cost.material.id)
		profile["materials"][id] = get_material_count(id) - cost.amount
		if profile["materials"][id] <= 0:
			profile["materials"].erase(id)
	profile["items"][str(item.id)] = get_item_count(str(item.id)) + 1
	add_rank_xp(Progression.CRAFT_XP_PER_TIER * item.tier)
	save_profile()
	return true


# --- Rank, skill points and tracks ----------------------------------------------------------

## Adds Rank XP; each Rank gained grants skill points (does not save; callers do).
## Returns the Rank-ups: [{ "level": n, "points": skill points granted }, ...].
func add_rank_xp(amount: int) -> Array[Dictionary]:
	var rank_ups: Array[Dictionary] = []
	if amount <= 0:
		return rank_ups
	var before: int = get_rank()
	profile["rank_xp"] = get_rank_xp() + amount
	for level: int in range(before + 1, get_rank() + 1):
		profile["skill_points"] = get_skill_points() + Progression.SKILL_POINTS_PER_RANK
		rank_ups.append({ "level": level, "points": Progression.SKILL_POINTS_PER_RANK })
	return rank_ups


func get_skill_points() -> int:
	return int(profile["skill_points"])


func get_track_level(track: String) -> int:
	return int(profile["track_levels"].get(track, 1))


func can_level_track(track: String) -> bool:
	return get_skill_points() >= Progression.TRACK_LEVEL_COST and get_track_level(track) < Progression.MAX_LEVEL


## Spends skill points to raise a track by one level, saves. Returns false if not allowed.
func level_track(track: String) -> bool:
	if not can_level_track(track):
		return false
	profile["skill_points"] = get_skill_points() - Progression.TRACK_LEVEL_COST
	profile["track_levels"][track] = get_track_level(track) + 1
	save_profile()
	return true


func get_rank_xp() -> int:
	return int(profile["rank_xp"])


func get_rank() -> int:
	return Progression.level_for_xp(get_rank_xp())


# --- Talents (per hero, bought with the shared skill points) ---------------------------------

## Why a talent can't be learned right now; &"" = it can. The Shrine shows these as text.
func talent_block(character: CharacterData, talent: TalentData) -> StringName:
	var owned: Array[TalentData] = owned_talents(character)
	if owned.has(talent):
		return &"owned"
	if talent.exclusive_group != &"":
		for other: TalentData in owned:
			if other.exclusive_group == talent.exclusive_group:
				return &"other_chosen"
	if talent.tier > 1 and not owned.any(func(t: TalentData) -> bool: return t.tier == talent.tier - 1):
		return &"needs_tier"
	if get_skill_points() < talent.cost():
		return &"no_points"
	return &""


## Spends the points, saves. Returns false (and changes nothing) if not allowed.
func buy_talent(character: CharacterData, talent: TalentData) -> bool:
	if talent_block(character, talent) != &"":
		return false
	profile["skill_points"] = get_skill_points() - talent.cost()
	var ids: Array = profile["talents"].get_or_add(str(character.id), [])
	ids.append(str(talent.id))
	save_profile()
	return true


## The talents this hero has learned (only ones that still exist in their tree).
func owned_talents(character: CharacterData) -> Array[TalentData]:
	var ids: Array = profile["talents"].get(str(character.id), [])
	var owned: Array[TalentData] = []
	for talent: TalentData in character.talents:
		if ids.has(str(talent.id)):
			owned.append(talent)
	return owned


# --- Character -------------------------------------------------------------------------------

func get_character() -> CharacterData:
	return CharacterRegistry.get_by_id(profile["character"])


func select_character(character: CharacterData) -> void:
	profile["character"] = str(character.id)
	save_profile()


# --- Loadout (per character; character_id "" = the chosen character) -------------------------

func get_equipped(slot: ItemData.Slot, character_id: String = "") -> ItemData:
	var id: String = _loadout(character_id)[_slot_key(slot)]
	return ItemRegistry.get_by_id(id) if id != "" else null


## Everything worn, per slot (two daggers = two entries; a two-hander is stored once, in the main hand).
func equipped_items(character_id: String = "") -> Array[ItemData]:
	var items: Array[ItemData] = []
	for slot: ItemData.Slot in ItemData.Slot.values():
		var item: ItemData = get_equipped(slot, character_id)
		if item:
			items.append(item)
	return items


func is_equipped(item: ItemData) -> bool:
	return _loadout().values().has(str(item.id))


## True if a two-handed weapon is filling the off hand right now.
func hands_full() -> bool:
	var main: ItemData = get_equipped(ItemData.Slot.MAIN_HAND)
	return main != null and main.two_handed


## Puts an owned item in a slot (its own slot by default), applying the hand rules:
## two-handed clears the off hand; anything off-hand clears a two-hander from the main hand.
## Each worn slot uses one copy: with one dagger, equipping it in the other hand moves it;
## with two, you dual-wield them. Gear above your mastery tier can't be equipped.
func equip(item: ItemData, slot: int = -1) -> bool:
	var target: ItemData.Slot = item.slot if slot < 0 else slot as ItemData.Slot
	if not has_item(str(item.id)) or not item.can_go_in(target) or not can_use_tier(item):
		return false
	var equipped: Dictionary = _loadout()
	if equipped.values().count(str(item.id)) >= get_item_count(str(item.id)):
		for key: String in equipped:
			if equipped[key] == str(item.id):
				equipped[key] = ""
	if item.two_handed:
		equipped[_slot_key(ItemData.Slot.OFF_HAND)] = ""
	elif target == ItemData.Slot.OFF_HAND and hands_full():
		equipped[_slot_key(ItemData.Slot.MAIN_HAND)] = ""
	equipped[_slot_key(target)] = str(item.id)
	save_profile()
	return true


func unequip(slot: ItemData.Slot) -> void:
	_loadout()[_slot_key(slot)] = ""
	save_profile()


## Uses up one copy of the equipped consumable (saved right away, so quitting mid-run can't
## refund it). When the last copy is gone, every character's loadout lets go of it.
## Returns false if there's none.
func consume_equipped() -> bool:
	var item: ItemData = get_equipped(ItemData.Slot.CONSUMABLE)
	if item == null or not has_item(str(item.id)):
		return false
	var id: String = str(item.id)
	profile["items"][id] = get_item_count(id) - 1
	if profile["items"][id] <= 0:
		profile["items"].erase(id)
		for loadout: Dictionary in profile["loadouts"].values():
			if loadout.get(_slot_key(ItemData.Slot.CONSUMABLE)) == id:
				loadout[_slot_key(ItemData.Slot.CONSUMABLE)] = ""
	save_profile()
	return true


## A character's { slot key: item id } ("" = the chosen character), created empty the first time.
func _loadout(character_id: String = "") -> Dictionary:
	var id: String = character_id if character_id != "" else str(get_character().id)
	if not profile["loadouts"].has(id):
		profile["loadouts"][id] = _empty_loadout()
	return profile["loadouts"][id]


func _empty_loadout() -> Dictionary:
	var loadout: Dictionary = {}
	for slot: ItemData.Slot in ItemData.Slot.values():
		loadout[_slot_key(slot)] = ""
	return loadout


## "main_hand", "chest"...: readable keys in the save file.
func _slot_key(slot: ItemData.Slot) -> String:
	return ItemData.Slot.keys()[slot].to_lower()


# --- Migration -------------------------------------------------------------------------------

## Upgrades older save formats one version at a time, then cleans up types.
func _migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("version", 1))
	var old_equipped: Dictionary = data.get("equipped", {})
	if version < 2:
		# v1 had three slots: weapon -> main hand, armor -> chest, trinket stays.
		old_equipped = {
			"main_hand": old_equipped.get("weapon", ""),
			"chest": old_equipped.get("armor", ""),
			"trinket": old_equipped.get("trinket", ""),
		}
	var merged: Dictionary = new_profile()
	merged.merge(data, true)
	# JSON has no integers: every number comes back as a float. Turn counts back into ints.
	merged["currency"] = int(merged["currency"])
	merged["skill_points"] = int(merged["skill_points"])
	merged["rank_xp"] = int(merged["rank_xp"])
	var track_levels: Dictionary = {}
	for track: Variant in merged["track_levels"]:
		track_levels[str(track)] = int(merged["track_levels"][track])
	if version < 4:
		# v3 tracks levelled from their own XP: keep those levels, then grant the skill points
		# your Rank has earned that those free levels didn't already cover.
		var old_xp: Dictionary = merged.get("xp", {})
		var spent: int = 0
		for track: Variant in old_xp:
			var level: int = Progression.level_for_xp(int(old_xp[track]), V3_TRACK_CURVE)
			if level > 1:
				track_levels[str(track)] = level
				spent += (level - 1) * Progression.TRACK_LEVEL_COST
		var earned: int = (Progression.level_for_xp(merged["rank_xp"]) - 1) * Progression.SKILL_POINTS_PER_RANK
		merged["skill_points"] = maxi(earned - spent, 0)
	merged.erase("xp")
	merged["track_levels"] = track_levels
	var materials: Dictionary = {}
	for id: Variant in merged["materials"]:
		materials[str(id)] = int(merged["materials"][id])
	merged["materials"] = materials
	var items: Dictionary = {}
	if merged["items"] is Array:
		for id: Variant in merged["items"]: # v2 and older: a list of owned ids (one copy each).
			items[str(id)] = 1
	else:
		for id: Variant in merged["items"]:
			items[str(id)] = int(merged["items"][id])
	merged["items"] = items
	var stats: Dictionary = new_profile()["stats"]
	stats.merge(merged["stats"], true)
	for key: String in stats:
		stats[key] = int(stats[key])
	merged["stats"] = stats
	profile = merged # _clean_equipped checks mastery levels from this profile.
	var loadouts: Dictionary = {}
	if version < 5:
		# v4 and older had one loadout: every character starts wearing it (copies are shared).
		for character: CharacterData in CharacterRegistry.all():
			loadouts[str(character.id)] = old_equipped
	else:
		loadouts = merged["loadouts"]
	merged.erase("equipped")
	var talents: Dictionary = {}
	for id: Variant in merged["talents"]:
		var list: Array = []
		for talent_id: Variant in merged["talents"][id]:
			list.append(str(talent_id))
		talents[str(id)] = list
	merged["talents"] = talents
	merged["character"] = str(merged["character"])
	var cleaned: Dictionary = {}
	for id: Variant in loadouts:
		cleaned[str(id)] = _clean_equipped(loadouts[id], items)
	merged["loadouts"] = cleaned
	merged["version"] = SAVE_VERSION
	return merged


## Keeps only equips that are owned, still fit their slot, and are within your mastery
## (item data and rules can change between versions).
func _clean_equipped(saved: Dictionary, owned: Dictionary) -> Dictionary:
	var equipped: Dictionary = _empty_loadout()
	for slot: ItemData.Slot in ItemData.Slot.values():
		var key: String = _slot_key(slot)
		var id: String = str(saved.get(key, ""))
		var item: ItemData = ItemRegistry.get_by_id(id) if owned.has(id) else null
		if item and item.can_go_in(slot) and can_use_tier(item):
			equipped[key] = id
	return equipped
