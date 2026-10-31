class_name Element
extends RefCounted
## The damage elements. No element = PHYSICAL, which never applies a status.

enum Type { PHYSICAL, FIRE, ICE, POISON }


## Translation key for an element's name, e.g. "ELEMENT_FIRE". Its text starts with a symbol
## so elements are never told apart by color alone.
static func name_key(type: Type) -> String:
	return "ELEMENT_" + Type.keys()[type]
