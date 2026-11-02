class_name HazardData
extends Resource
## A boss's lasting danger, and the potion that counters it. Set on ObjectiveData.hazard, shown in the
## Mission Board's scouting report, active from the moment the boss appears (HazardComponent).

enum Kind { SLOW_STAMINA, SHRINK_MAX_HP }

@export var name_key: String = ""
@export var effect_key: String = "" ## What it does, for the scouting report and the HUD.
@export var kind: Kind = Kind.SLOW_STAMINA
## The ItemData id of the potion that counters it (an id: the potion's booster already points back here).
@export var counter_item_id: String = ""

@export_group("Slow Stamina")
@export var stamina_regen_scale: float = 0.4 ## 0.4 = stamina refills at 40% speed.

@export_group("Shrink Max HP")
@export var shrink_per_tick: float = 0.03 ## Share of max HP lost each tick.
@export var shrink_interval: float = 5.0 ## Seconds between ticks.
@export var shrink_limit: float = 0.5 ## Never takes more than this share, so it can't kill by itself.
