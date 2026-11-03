class_name Market
extends RefCounted
## Coins: what missions pay, what the camp's Marketplace buys and sells for, and the rules for both.
## Coins are the profile's "currency". Prices live in the data: ObjectiveData coin_reward /
## coins_per_progress, MaterialData.sell_price, ItemData.shop_price. Items sell for a share of their
## recipe's material value, so new gear needs no price of its own.

const ITEM_SELL_SHARE: float = 0.5 ## Gear sells for half of what its materials would fetch.
const DEFAULT_PRICE_PER_TIER: int = 3 ## A material with no sell_price of its own: 3 coins per tier.


static func coins() -> int:
	return int(SaveManager.profile["currency"])


# --- Missions --------------------------------------------------------------------------------

## The coins a finished mission pays, stored in GameState.run_rewards["coins"] so the challenge
## and Expedition bonuses multiply them with the rest. Call once, before those bonuses.
## Normal missions pay only when won. Endless modes and Classic pay for how far you got however
## they end, and Classic adds its own reward when cleared.
static func add_run_coins(mode: ObjectiveData, run: ModeRun, victory: bool) -> int:
	var amount: int = mode.coin_reward if victory else 0
	if mode.coins_per_progress > 0:
		amount += mode.coins_per_progress * progress(mode, run)
	if amount > 0:
		GameState.run_rewards["coins"] = int(GameState.run_rewards.get("coins", 0)) + amount
	return amount


## The Mission Board's line: "Coins: 200 if won". Before any bonus. "" = pays none.
static func reward_text(mode: ObjectiveData) -> String:
	var parts: Array[String] = []
	if mode.coins_per_progress > 0:
		var per_key: String = "UI_COINS_PER_WAVE" if mode.type == ObjectiveData.Type.ENDLESS_SURVIVAL else "UI_COINS_PER_BOSS"
		parts.append(TranslationServer.translate(per_key) % mode.coins_per_progress)
	if mode.coin_reward > 0:
		# An Expedition's victory bonus multiplies the coins too, so show what's really paid.
		parts.append(TranslationServer.translate("UI_COINS_IF_WON") % ceili(mode.coin_reward * maxf(mode.victory_reward_multiplier, 1.0)))
	if parts.is_empty():
		return ""
	return TranslationServer.translate("UI_COINS_REWARD") % ", ".join(parts)


## How far a run went: waves reached (Endless Survival) or bosses beaten (Endless Boss, Classic).
static func progress(mode: ObjectiveData, run: ModeRun) -> int:
	if mode.type == ObjectiveData.Type.ENDLESS_SURVIVAL:
		return GameState.wave
	return run.bosses_defeated() if run else 0


# --- Prices ----------------------------------------------------------------------------------

static func material_price(material: MaterialData) -> int:
	if material == null:
		return 0
	return material.sell_price if material.sell_price > 0 else DEFAULT_PRICE_PER_TIER * material.tier


## Half the value of the recipe's materials, rounded up, at least 1. 0 = can't be sold (no recipe).
static func item_price(item: ItemData) -> int:
	var value: int = 0
	for cost: MaterialCost in item.cost:
		value += material_price(cost.material) * cost.amount
	return maxi(ceili(value * ITEM_SELL_SHARE), 1) if value > 0 else 0


# --- Selling ---------------------------------------------------------------------------------

## Copies of an item worn by any hero or packed in any hero's Inventory: these can't be sold.
static func item_in_use(item_id: String) -> int:
	var used: int = 0
	for loadout: Dictionary in SaveManager.profile["loadouts"].values():
		used += loadout.values().count(item_id)
	return used + SaveManager.get_item_count(item_id) - SaveManager.pack_available(item_id)


static func sellable_items(item_id: String) -> int:
	return maxi(SaveManager.get_item_count(item_id) - item_in_use(item_id), 0)


## Sells up to `amount` copies, saves. Returns the coins earned (0 = nothing sold).
## Recipes stay known: discovered materials are never forgotten.
static func sell_material(material: MaterialData, amount: int) -> int:
	var id: String = str(material.id)
	var count: int = mini(amount, SaveManager.get_material_count(id))
	if count <= 0:
		return 0
	_take(SaveManager.profile["materials"], id, count)
	return _pay(count * material_price(material))


static func sell_item(item: ItemData, amount: int) -> int:
	var id: String = str(item.id)
	var count: int = mini(amount, sellable_items(id))
	if count <= 0 or item_price(item) <= 0:
		return 0
	_take(SaveManager.profile["items"], id, count)
	return _pay(count * item_price(item))


# --- Buying (the shop sells consumables only, for now) ---------------------------------------

## Everything the shop sells: potions with a shop_price, cheapest first.
static func stock() -> Array[ItemData]:
	var items: Array[ItemData] = ItemRegistry.all().filter(
		func(item: ItemData) -> bool: return item.slot == ItemData.Slot.CONSUMABLE and item.shop_price > 0)
	items.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.shop_price < b.shop_price)
	return items


static func can_buy(item: ItemData) -> bool:
	return stock().has(item) and coins() >= item.shop_price


## Pays, adds one copy to camp (not to the Inventory), saves. Returns false if not allowed.
static func buy(item: ItemData) -> bool:
	if not can_buy(item):
		return false
	SaveManager.profile["currency"] = coins() - item.shop_price
	var id: String = str(item.id)
	SaveManager.profile["items"][id] = SaveManager.get_item_count(id) + 1
	SaveManager.save_profile()
	return true


static func _take(counts: Dictionary, id: String, amount: int) -> void:
	counts[id] = int(counts.get(id, 0)) - amount
	if counts[id] <= 0:
		counts.erase(id)


static func _pay(amount: int) -> int:
	SaveManager.profile["currency"] = coins() + amount
	SaveManager.save_profile()
	return amount
