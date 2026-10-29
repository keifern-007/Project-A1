class_name PassiveData
extends Resource
## A character's always-on passive, saved as a .tres in resources/passives/.
## `kind` picks the behavior (PassiveComponent runs it); the groups below hold its numbers.

enum Kind { BLOODRUSH, BULWARK, ATTUNEMENT }

@export var name_key: String = ""
@export var kind: Kind = Kind.BLOODRUSH

@export_group("Bloodrush") ## Kills stack bonus damage for a short time.
@export var damage_per_stack: float = 0.04 ## 0.04 = +4% damage per stack.
@export var max_stacks: int = 5
@export var stack_duration: float = 4.0 ## Seconds; another kill refreshes it.

@export_group("Bulwark") ## Tougher: less damage taken, optionally no knockback.
@export var damage_reduction: float = 0.2 ## 0.2 = hits deal 20% less.
@export var knockback_immune: bool = true

@export_group("Attunement") ## Faster skill cooldowns.
@export var cooldown_speed: float = 1.3 ## 1.3 = cooldowns tick 30% faster.


## Player-facing text built from the numbers, so tuning a value updates the card too.
func describe() -> String:
	match kind:
		Kind.BLOODRUSH:
			return TranslationServer.translate("PASSIVE_BLOODRUSH_DESC") % [
				roundi(damage_per_stack * 100.0), roundi(stack_duration), max_stacks]
		Kind.BULWARK:
			var text: String = TranslationServer.translate("PASSIVE_BULWARK_DESC") % roundi(damage_reduction * 100.0)
			if knockback_immune:
				text += " " + TranslationServer.translate("PASSIVE_NO_KNOCKBACK")
			return text
		_:
			return TranslationServer.translate("PASSIVE_ATTUNEMENT_DESC") % roundi((cooldown_speed - 1.0) * 100.0)
