class_name Combat
extends RefCounted
## All damage math lives here, so in co-op it can run on the host only.

const MIN_DAMAGE: int = 1
const MAX_BLOCK_FRACTION: float = 0.6 ## Defense can never stop more than this much of a hit.


## Defense subtracts from the hit, up to the cap. Negative defense (gear trade-offs) adds damage.
static func calculate_damage(base_damage: int, defense: int) -> int:
	var blocked: int = mini(defense, floori(base_damage * MAX_BLOCK_FRACTION))
	return maxi(base_damage - blocked, MIN_DAMAGE)
