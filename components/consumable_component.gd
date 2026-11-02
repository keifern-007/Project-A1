class_name ConsumableComponent
extends Node
## The hero's Inventory during a run: one slot is selected. Press the key to use one copy (heal,
## damage boost...), then wait out its cooldown, which every potion shares. Another key selects the
## next stack. Copies come from the saved profile, so they're really spent.

signal used(item: ItemData) ## Hook for drink sounds.
signal changed ## Count or selection changed; the HUD redraws.

@export var boosters: BoosterComponent
@export var health: HealthComponent
@export var mana: MeterComponent ## Optional: so a mana potion at full mana isn't wasted.

var item: ItemData = null ## The selected stack's potion. null = nothing left to use.
var cooldown_left: float = 0.0
var cooldown_total: float = 0.0 ## Length of the running cooldown (the HUD's bar).
var locked: bool = false ## The tutorial sets this, so practice can't spend a real potion.

var _selected: int = -1


func _ready() -> void:
	_select_from(0)


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func get_count() -> int:
	return int(SaveManager.get_pack()[_selected].get("count", 0)) if _selected >= 0 else 0


## True if pressing the 'next' key would change anything.
func can_cycle() -> bool:
	return SaveManager.get_pack().filter(func(entry: Dictionary) -> bool: return not entry.is_empty()).size() > 1


## Selects the next stack, wrapping around.
func cycle() -> void:
	if can_cycle():
		_select_from(_selected + 1)
		changed.emit()


## Returns true if one was used. A heal at full HP (or mana potion at full mana) is refused,
## so a misclick doesn't waste it.
func try_use() -> bool:
	if locked or item == null or item.use_effect == null or cooldown_left > 0.0:
		return false
	if item.use_effect.effect == BoosterData.Effect.HEAL and health.current >= health.max_health:
		return false
	if item.use_effect.effect == BoosterData.Effect.RESTORE_MANA and mana and mana.is_full():
		return false
	if item.use_effect.effect == BoosterData.Effect.HAZARD_WARD and not (boosters.hazards and boosters.hazards.can_ward(item.use_effect.ward)):
		return false # Only useful against its own boss's hazard.
	var drunk: ItemData = item
	if not SaveManager.use_pack_slot(_selected):
		return false
	boosters.apply(drunk.use_effect)
	cooldown_total = drunk.use_cooldown
	cooldown_left = cooldown_total
	if get_count() == 0: # That stack ran out: the next one is ready to go.
		_select_from(_selected + 1)
	used.emit(drunk)
	changed.emit()
	return true


## Selects the first stack at or after `start`, wrapping around. None left = item stays null.
func _select_from(start: int) -> void:
	var pack: Array = SaveManager.get_pack()
	_selected = -1
	item = null
	for offset: int in pack.size():
		var index: int = (start + offset) % pack.size()
		if not (pack[index] as Dictionary).is_empty():
			_selected = index
			item = ItemRegistry.get_by_id(str(pack[index]["id"]))
			return
