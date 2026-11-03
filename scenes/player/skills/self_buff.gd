extends SkillEffect
## A skill that changes the caster for a while instead of hitting anything: Rage Burst, Bloodthirst,
## Sprint, Stamina Surge. Each scene sets the numbers; anything left at its default does nothing.
## The HUD names what's active, so it never relies on the particles or their color.

const NO_AURA: int = -2

@export var duration: float = 5.0 ## 0 = happens once, right away.
@export var status_key: String = "" ## HUD line while active, e.g. "HUD_BUFF_RAGE".
@export var damage_multiplier: float = 1.0
@export var damage_taken_multiplier: float = 1.0
@export var speed_multiplier: float = 1.0
@export_range(0.0, 1.0) var kill_heal_fraction: float = 0.0 ## Share of max HP healed per kill.
@export var stamina_restored: float = 0.0
@export var aura: int = NO_AURA ## An Element.Type or SkillFx.ARCANE: particles around the caster.

var _player: Player
var _source: StringName
var _aura: CPUParticles3D


func _ready() -> void:
	_player = caster as Player
	_source = StringName(status_key)
	if stamina_restored > 0.0:
		_player.stamina.restore(stamina_restored)
	if aura != NO_AURA:
		SkillFx.burst(get_parent(), _player.global_position + Vector3.UP, aura, 1.5)
	if duration <= 0.0:
		queue_free()
		return
	_player.skill_caster.stats.set_damage_modifier(_source, damage_multiplier)
	_player.hurtbox.damage_taken_multiplier *= damage_taken_multiplier
	_player.set_speed_boost(_source, speed_multiplier)
	if kill_heal_fraction > 0.0:
		EventBus.enemy_killed.connect(_on_enemy_killed) # Phase 5: only this player's kills.
	if status_key != "":
		_player.skill_caster.show_timed_status(status_key, duration)
	if aura != NO_AURA:
		_aura = SkillFx.make_trail(aura, 1.3)
		_aura.position = Vector3.UP
		add_child(_aura)
	get_tree().create_timer(duration, false, true).timeout.connect(_end)


func _physics_process(_delta: float) -> void:
	if is_instance_valid(caster):
		global_position = caster.global_position


func _on_enemy_killed(_enemy: Node) -> void:
	_player.health.heal(maxi(roundi(_player.health.max_health * kill_heal_fraction), 1))


func _end() -> void:
	if is_instance_valid(_player):
		_player.skill_caster.stats.set_damage_modifier(_source, 1.0)
		_player.hurtbox.damage_taken_multiplier /= damage_taken_multiplier
		_player.set_speed_boost(_source, 1.0)
	SkillFx.release_trail(_aura, get_parent())
	queue_free()
