class_name CampHeroes
extends Node
## Every hero lives in the camp at once: one body per HeroArea. One of them is controlled by you;
## the rest are NPCs idling in their areas. Walking up to an NPC hero (interact) asks the hub to
## show their card; confirming hands control over and the old hero walks back home.

signal hero_requested(character: CharacterData) ## Someone interacted with an NPC hero.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const INTERACTABLE_SCENE: PackedScene = preload("res://scenes/maps/interactable.tscn")
const ARRIVE_DISTANCE: float = 0.3
## Straight-line walking can snag on the campfire or a station: no progress for this long = pop home.
const STUCK_TIME: float = 2.0
const PROGRESS_STEP: float = 0.5

var controlled: Player = null

var _heroes: Dictionary = {} # CharacterData -> Player
var _areas: Dictionary = {} # CharacterData -> HeroArea
var _prompts: Dictionary = {} # Player -> Interactable
var _walking: Dictionary = {} # Player -> { "stuck": float, "from": Vector3 }
var _look_at: Vector3 = Vector3.ZERO


## Spawns a hero at every HeroArea in the world, all as NPCs. `look_at` = what idle heroes face.
func setup(world: Node3D, look_at: Vector3) -> void:
	_look_at = look_at
	for node: Node in get_tree().get_nodes_in_group("hero_areas"):
		var area: HeroArea = node as HeroArea
		var hero: Player = PLAYER_SCENE.instantiate()
		(hero.get_node("CharacterComponent") as CharacterComponent).data = area.character
		hero.controlled = false
		hero.combat_enabled = false
		world.add_child(hero)
		hero.global_position = area.global_position
		hero.face_toward(_look_at)
		var prompt: Interactable = INTERACTABLE_SCENE.instantiate()
		prompt.action = &"hero"
		prompt.prompt_key = area.character.name_key
		hero.add_child(prompt)
		prompt.interacted.connect(func(_by: Player) -> void: hero_requested.emit(area.character))
		_heroes[area.character] = hero
		_areas[area.character] = area
		_prompts[hero] = prompt


## Heroes in screen order: left, middle, right (for arrow-key browsing).
func characters() -> Array[CharacterData]:
	var list: Array[CharacterData] = []
	list.assign(_areas.keys())
	list.sort_custom(func(a: CharacterData, b: CharacterData) -> bool:
		if _areas[a].side != _areas[b].side:
			return _areas[a].side < _areas[b].side # ScreenSide is already in screen order.
		return a.sort_order < b.sort_order)
	return list


func area_of(character: CharacterData) -> HeroArea:
	return _areas.get(character)


func hero_of(character: CharacterData) -> Player:
	return _heroes.get(character)


## The character a clicked body belongs to, or null.
func character_of(body: Node) -> CharacterData:
	for character: CharacterData in _heroes:
		if _heroes[character] == body:
			return character
	return null


## You now play `character`; the previous hero becomes an NPC and walks home.
func control(character: CharacterData) -> Player:
	var hero: Player = _heroes[character]
	if controlled == hero:
		return hero
	if controlled:
		controlled.set_controlled(false)
		(_prompts[controlled] as Interactable).enabled = true
		_walking[controlled] = { "stuck": 0.0, "from": controlled.global_position }
	_walking.erase(hero)
	hero.set_controlled(true)
	(_prompts[hero] as Interactable).enabled = false
	controlled = hero
	return hero


func _physics_process(delta: float) -> void:
	for hero: Player in _walking.keys():
		var home: Vector3 = _areas[(hero.get_node("CharacterComponent") as CharacterComponent).data].global_position
		var to_home: Vector3 = home - hero.global_position
		to_home.y = 0.0
		var state: Dictionary = _walking[hero]
		if hero.global_position.distance_to(state["from"]) > PROGRESS_STEP:
			state["from"] = hero.global_position
			state["stuck"] = 0.0
		else:
			state["stuck"] += delta
		if to_home.length() <= ARRIVE_DISTANCE or state["stuck"] >= STUCK_TIME:
			if state["stuck"] >= STUCK_TIME:
				hero.global_position = home
				hero.velocity = Vector3.ZERO
			hero.input.scripted_direction = Vector3.ZERO
			hero.face_toward(_look_at)
			_walking.erase(hero)
		else:
			hero.input.scripted_direction = to_home.normalized()
