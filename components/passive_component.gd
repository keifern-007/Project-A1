class_name PassiveComponent
extends Node
## Runs the character's passive (PassiveData). Hooks into sibling components it's given:
## Bloodrush -> damage modifier on kills, Bulwark -> hurtbox damage + knockback,
## Attunement -> skill cooldown speed.

const BLOODRUSH_SOURCE: StringName = &"bloodrush"

@export var character: CharacterComponent
@export var stats: StatsComponent
@export var hurtbox: HurtboxComponent
@export var skill_caster: SkillCasterComponent
@export var talents: TalentComponent ## Optional: talents can make the passive stronger.

var passive: PassiveData = null
var bonus: float = 0.0 ## From talents: 0.5 = the passive's main number is 50% stronger.
var stacks: int = 0
var stack_time_left: float = 0.0


func _ready() -> void:
	passive = character.data.passive if character.data else null
	if passive == null:
		return
	bonus = talents.passive_bonus() if talents else 0.0
	match passive.kind:
		PassiveData.Kind.BLOODRUSH:
			# Phase 5: count only this player's kills once kills carry a killer.
			EventBus.enemy_killed.connect(_on_enemy_killed)
		PassiveData.Kind.BULWARK:
			hurtbox.damage_taken_multiplier *= 1.0 - minf(passive.damage_reduction * (1.0 + bonus), 0.9)
		PassiveData.Kind.ATTUNEMENT:
			skill_caster.cooldown_speed = 1.0 + (passive.cooldown_speed - 1.0) * (1.0 + bonus)


func _physics_process(delta: float) -> void:
	if stacks == 0:
		return
	stack_time_left -= delta
	if stack_time_left <= 0.0:
		stacks = 0
		stats.set_damage_modifier(BLOODRUSH_SOURCE, 1.0)


## How much knockback this body takes (0 = immune). The Player asks when it's hit.
func knockback_taken() -> float:
	if passive and passive.kind == PassiveData.Kind.BULWARK and passive.knockback_immune:
		return 0.0
	return 1.0


## Short HUD line while the passive is doing something, e.g. "Bloodrush x3  2s". "" = nothing to show.
func status_text() -> String:
	if stacks == 0:
		return ""
	return tr("HUD_PASSIVE_STACKS") % [tr(passive.name_key), stacks, ceili(stack_time_left)]


func _on_enemy_killed(_enemy: Node) -> void:
	stacks = mini(stacks + 1, passive.max_stacks)
	stack_time_left = passive.stack_duration
	stats.set_damage_modifier(BLOODRUSH_SOURCE, 1.0 + passive.damage_per_stack * (1.0 + bonus) * stacks)
