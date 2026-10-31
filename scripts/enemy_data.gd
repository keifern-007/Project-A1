class_name EnemyData
extends Resource
## One enemy type, saved as a .tres in resources/enemies/. A biome variant is a full EnemyData of its
## own (stats, weaknesses, drops), listed in the base type's `variants`.

@export var name_key: String = "" ## Translation key, e.g. "ENEMY_GOBLIN".

@export_group("Stats")
@export var max_health: int = 30
@export var attack_power: int = 8
@export var defense: int = 0
@export var move_speed: float = 3.5
@export_range(0.0, 1.0) var knockback_resistance: float = 0.0 ## 1 = immovable (bosses).

@export_group("Elements")
## Damage scale per element: 1.5 = weak to it, 0.5 = resists it.
@export var fire_multiplier: float = 1.0
@export var ice_multiplier: float = 1.0
@export var poison_multiplier: float = 1.0
@export var can_be_frozen: bool = true

@export_group("Behaviour")
@export var detection_range: float = 10.0 ## Starts chasing when a player gets this close.
@export var attack_range: float = 1.6
@export var attack_windup: float = 0.4 ## Telegraph time before the hit — the player's dodge window.
@export var attack_recovery: float = 0.6 ## Pause after swinging, the player's punish window.

@export_group("Ranged") ## Ranged enemies (Slinger). attack_range = farthest throw.
@export var projectile_scene: PackedScene ## Root script must be LobbedShot.
@export var projectile_element: Element.Type = Element.Type.PHYSICAL ## Frost throws ice, Mummified cursed sand.
@export var attack_cooldown: float = 2.0 ## Seconds between throws.
@export var retreat_range: float = 4.0 ## Backs away when a player is closer than this.

@export_group("Charge") ## Chargers (Tusker). attack_range = distance it starts a charge from.
@export var charge_speed: float = 14.0
@export var charge_distance: float = 12.0 ## Stops after this far if it hits nothing.
@export var stun_time: float = 2.0 ## Dazed after crashing into a wall or rock: the punish window.

@export_group("Guard") ## Shield bearers (Shieldback).
@export_range(0.0, 1.0) var guard_multiplier: float = 0.2 ## Damage taken from the front.
@export var guard_angle_degrees: float = 70.0 ## Half-width of the shielded front.
@export var guard_break_time: float = 2.0 ## Shield knocked aside by a heavy hit.
@export var turn_speed: float = 2.5 ## Radians/sec: slow turning makes flanking work.

@export_group("Support") ## Supports (Goblin Shaman). attack_range = how far it stays from you; attack_cooldown = time between wards.
@export var ward_duration: float = 4.0
@export_range(0.0, 1.0) var ward_multiplier: float = 0.5 ## Damage the warded ally takes.
@export var ward_range: float = 10.0 ## Allies farther than this from the shaman can't be warded.

@export_group("Exploder") ## Exploders (Puffcap). attack_range = how close it gets before swelling; attack_windup = swell time.
@export var burst_scene: PackedScene ## Root script must be PoisonCloud.
@export var cloud_duration: float = 4.0 ## How long the cloud lingers after the burst.
@export_range(0.0, 1.0) var cloud_damage_fraction: float = 0.25 ## Cloud hits = attack_power × this; the burst hits for the full amount.

@export_group("Rewards")
@export var xp_reward: int = 5
@export var drops: Array[DropEntry] = []

@export_group("Biome")
@export var biome: BiomeData ## Variants only: the biome this one appears in.
@export var variants: Array[EnemyData] = [] ## Base types only.
@export var tint: Color = Color.WHITE ## Multiplies the placeholder look.
## Added to the enemy's visual so a variant differs by shape too, never color alone.
@export var accessory: PackedScene
@export var accessory_scale: float = 1.0

@export_group("Accessibility")
## Spider-type enemies get an alternate look when arachnophobia mode is on (Phase 6).
@export var is_arachnid: bool = false

var _tinted_materials: Dictionary = {} # Scene material -> this type's tinted copy.


func element_multiplier(element: Element.Type) -> float:
	match element:
		Element.Type.FIRE:
			return fire_multiplier
		Element.Type.ICE:
			return ice_multiplier
		Element.Type.POISON:
			return poison_multiplier
	return 1.0


## The version of this enemy to use in a biome (itself if it has none there).
func variant_for(for_biome: BiomeData) -> EnemyData:
	for variant: EnemyData in variants:
		if variant.biome == for_biome:
			return variant
	return self


## Applies tint and accessory to the enemy's visual. Enemies of a type share tinted materials.
func apply_look(visual: Node3D) -> void:
	if tint != Color.WHITE:
		for child: Node in visual.find_children("*", "MeshInstance3D", true, false):
			_tint_mesh(child as MeshInstance3D)
	if accessory:
		var extra: Node3D = accessory.instantiate()
		extra.scale = Vector3.ONE * accessory_scale
		visual.add_child(extra)


func _tint_mesh(mesh: MeshInstance3D) -> void:
	var base: StandardMaterial3D = mesh.get_surface_override_material(0) as StandardMaterial3D
	if base == null:
		return
	if not _tinted_materials.has(base):
		var tinted: StandardMaterial3D = base.duplicate()
		tinted.albedo_color = base.albedo_color * tint
		_tinted_materials[base] = tinted
	mesh.set_surface_override_material(0, _tinted_materials[base])
