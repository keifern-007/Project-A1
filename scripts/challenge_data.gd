class_name ChallengeData
extends Resource
## A mission difficulty (Normal, Hard, Brutal...), picked on the Mission Board for any map + objective.
## Optional by design: Normal is always there, so casual players can ignore challenges.
## Saved as a .tres in resources/challenges/.

@export var name_key: String = ""
@export var required_rank: int = 1 ## Locked on the Mission Board until this Rank.
@export var enemy_health_multiplier: float = 1.0 ## Every enemy and boss spawns with this much more HP.
@export var damage_taken_multiplier: float = 1.0 ## Hits on players hurt this much more.
## Materials and XP from a WON run are multiplied by this (defeat gets no bonus).
@export var reward_multiplier: float = 1.0


func is_harder() -> bool:
	return enemy_health_multiplier > 1.0 or damage_taken_multiplier > 1.0


## "Enemy HP +50%  |  Damage taken +30%  |  Rewards x1.5 on victory" for the Mission Board.
func describe() -> String:
	if not is_harder():
		return TranslationServer.translate("CHALLENGE_NORMAL_DESC")
	return TranslationServer.translate("CHALLENGE_DESC") % [roundi((enemy_health_multiplier - 1.0) * 100.0),
		roundi((damage_taken_multiplier - 1.0) * 100.0), reward_multiplier]
