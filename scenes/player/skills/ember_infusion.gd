extends SkillEffect
## Ember Infusion: the caster's basic attack deals this skill's element for a while. It hits nothing itself.

@export var duration: float = 10.0


func _ready() -> void:
	var player: Player = caster as Player
	if player:
		player.skill_caster.infuse_basic_attack(element, duration)
	queue_free()
