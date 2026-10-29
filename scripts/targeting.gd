class_name Targeting
extends RefCounted
## Shared "who should I go after?" logic for enemies and bosses.
## Co-op ready: works with any number of nodes in the "players" group.


## Nearest living player to `from`, ignoring height. Null if nobody is alive.
static func nearest_player(from: Node3D) -> Node3D:
	var nearest: Node3D = null
	var best: float = INF
	for node: Node in from.get_tree().get_nodes_in_group("players"):
		var player: Node3D = node as Node3D
		if player and is_alive(player):
			var dist: float = flat_distance(from.global_position, player.global_position)
			if dist < best:
				best = dist
				nearest = player
	return nearest


## Untyped on purpose: it's safe to pass a node that has already been freed.
static func is_alive(node: Variant) -> bool:
	if not is_instance_valid(node):
		return false
	return not node.has_method("is_alive") or node.call("is_alive")


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
