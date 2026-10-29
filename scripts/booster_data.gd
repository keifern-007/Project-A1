class_name BoosterData
extends Resource
## A consumable that takes effect the moment it's picked up (potions, tonics...).
## Saved as a .tres in resources/items/.

enum Effect { HEAL, DAMAGE_UP, RESTORE_MANA }

@export var name_key: String = "" ## Translation key, e.g. "ITEM_FURY_TONIC".
@export var effect: Effect = Effect.HEAL
## HEAL: HP restored. DAMAGE_UP: bonus as a fraction (0.3 = +30% damage). RESTORE_MANA: mana restored.
@export var value: float = 25.0
@export var duration: float = 0.0 ## Seconds, for timed effects. Ignored by HEAL.


## "Restores 40 HP" / "+25% damage for 15s", for the Forge and Gear Rack.
func describe() -> String:
	match effect:
		Effect.DAMAGE_UP:
			return TranslationServer.translate("EFFECT_DAMAGE_UP") % [roundi(value * 100.0), roundi(duration)]
		Effect.RESTORE_MANA:
			return TranslationServer.translate("EFFECT_MANA") % roundi(value)
		_:
			return TranslationServer.translate("EFFECT_HEAL") % roundi(value)
