class_name Combat
extends RefCounted
## All damage math lives here, so in co-op it can run on the host only.

const MIN_DAMAGE: int = 1


static func calculate_damage(base_damage: int, defense: int) -> int:
	return maxi(base_damage - defense, MIN_DAMAGE)
