class_name SiteScatter
extends Node3D
## Fills a big map with sites, differently each run. The map author marks open spots with Marker3D
## children (slots: cleared, flat, safe to build on) and tags them in metadata ("tags": "land",
## "river", "ridge"...). On load, every slot gets a site from `sites`, picked by weight with the run
## RNG (so co-op players get the same map), among those whose tags fit, with each kind kept under its
## max_count and no kind twice in a row. Sites farther from `origin` (base camp) get a higher level.
## This is the procedural part: the map's shape is hand-made, what you find in it changes.

@export var sites: Array[SiteEntry] = []
@export var origin: Vector3 = Vector3.ZERO ## Base camp: sites get tougher with distance from it.
@export var metres_per_level: float = 45.0
@export var max_level: int = 5


func _ready() -> void:
	var rng: RandomNumberGenerator = GameState.rng
	var counts: Dictionary = {}
	var last: SiteEntry = null
	var slots: Array[Node] = get_children().filter(func(child: Node) -> bool: return child is Marker3D)
	for slot: Marker3D in slots:
		var tags: PackedStringArray = slot.get_meta("tags", PackedStringArray(["land"]))
		var entry: SiteEntry = _pick(rng, tags, counts, last)
		if entry == null:
			continue
		counts[entry] = counts.get(entry, 0) + 1
		last = entry
		var site: Node3D = entry.scene.instantiate()
		var distance: float = Vector2(slot.global_position.x - origin.x, slot.global_position.z - origin.z).length()
		if site is MapRegion:
			(site as MapRegion).level = clampi(1 + floori(distance / metres_per_level), 1, max_level)
		# Only the decorations turn: enemies spawn inside the site and must stand in an unturned node.
		var props: Node3D = site.get_node_or_null("Props")
		var turn: float = rng.randf_range(0.0, TAU)
		if props:
			props.rotation.y = turn
		slot.add_child(site)


func _pick(rng: RandomNumberGenerator, tags: PackedStringArray, counts: Dictionary, last: SiteEntry) -> SiteEntry:
	var options: Array[SiteEntry] = []
	var total: float = 0.0
	for entry: SiteEntry in sites:
		if entry == last or counts.get(entry, 0) >= entry.max_count or not entry.fits(tags):
			continue
		options.append(entry)
		total += entry.weight
	var roll: float = rng.randf() * total
	for entry: SiteEntry in options:
		roll -= entry.weight
		if roll <= 0.0:
			return entry
	return options.back() if not options.is_empty() else null
