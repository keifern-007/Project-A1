class_name ConsumableComponent
extends Node
## The loadout's Consumable slot during a run: press the key to use one copy (heal, damage boost...),
## then wait out its cooldown. Copies come from the saved stack, so they're really spent.

signal used(item: ItemData) ## Hook for drink sounds.
signal changed ## Count or item changed; the HUD redraws.

@export var boosters: BoosterComponent
@export var health: HealthComponent
@export var mana: MeterComponent ## Optional: so a mana potion at full mana isn't wasted.

var item: ItemData = null
var cooldown_left: float = 0.0
var locked: bool = false ## The tutorial sets this, so practice can't spend a real potion.


func _ready() -> void:
	item = SaveManager.get_equipped(ItemData.Slot.CONSUMABLE)


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func get_count() -> int:
	return SaveManager.get_item_count(str(item.id)) if item else 0


## Returns true if one was used. A heal at full HP (or mana potion at full mana) is refused,
## so a misclick doesn't waste it.
func try_use() -> bool:
	if locked or item == null or item.use_effect == null or cooldown_left > 0.0 or get_count() <= 0:
		return false
	if item.use_effect.effect == BoosterData.Effect.HEAL and health.current >= health.max_health:
		return false
	if item.use_effect.effect == BoosterData.Effect.RESTORE_MANA and mana and mana.is_full():
		return false
	if not SaveManager.consume_equipped():
		return false
	boosters.apply(item.use_effect)
	cooldown_left = item.use_cooldown
	used.emit(item)
	changed.emit()
	return true
