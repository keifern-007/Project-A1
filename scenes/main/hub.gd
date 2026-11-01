extends Control
## The camp between runs: a walkable 3D hub. Walk up to a station and interact:
## Mission Board (pick and start a mission), Forge (craft gear), Gear Rack (equip it),
## Skill Shrine (spend skill points on tracks), Stash (what you own).
## Every hero lives here too (CampHeroes). First visit after the title screen: the camera glides
## from hero to hero while you browse their cards and pick who to play. Later, walk up to
## (or click) another hero to switch.

const CAMP_MAP: PackedScene = preload("res://scenes/maps/camp.tscn")
const MISSION_BOARD_PANEL: PackedScene = preload("res://scenes/main/mission_select.tscn")
const STASH_PANEL: PackedScene = preload("res://scenes/ui/stash_panel.tscn")
const FORGE_PANEL: PackedScene = preload("res://scenes/ui/forge_panel.tscn")
const LOADOUT_PANEL: PackedScene = preload("res://scenes/ui/loadout_panel.tscn")
const SHRINE_PANEL: PackedScene = preload("res://scenes/ui/shrine_panel.tscn")
const HERO_CARD: PackedScene = preload("res://scenes/ui/hero_card.tscn")
const OPTIONS_PANEL: PackedScene = preload("res://scenes/ui/options_panel.tscn")
const TUTORIAL_PROMPT: PackedScene = preload("res://scenes/ui/tutorial_prompt.tscn")
const TOAST_TIME: float = 2.0
const CHOOSE_ZOOM: float = 16.0 ## A bit wider than play zoom while picking a hero.
## While choosing, the browsed hero sits this far (world units) from screen center, away from their card.
const CHOOSE_SHIFT: float = 5.5
const ZOOM_TIME: float = 0.7
const PLAYER_LAYER: int = 2 ## Physics layer 2 (bit value 2) = player bodies, for click picking.

var _heroes: CampHeroes
var _camera: CameraFollow
var _overview: Node3D ## Camp center: idle heroes face it.
var _focus: Node3D = Node3D.new() ## What the camera follows while choosing.
var _play_zoom: float
var _choosing: bool = false ## Nobody played yet: overview + browsing cards.
var _card_character: CharacterData
var _open_panel: Control = null

@onready var retro_screen: RetroScreen = $RetroScreen
@onready var panel_host: Control = %PanelHost
@onready var toast: Label = %Toast
@onready var hint_label: Label = %HintLabel
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	var world: Node3D = CAMP_MAP.instantiate()
	retro_screen.add_world(world)
	_camera = world.get_node("Camera3D")
	_overview = world.get_node("Overview")
	_play_zoom = _camera.size
	_heroes = CampHeroes.new()
	_heroes.name = "CampHeroes"
	add_child(_heroes)
	_heroes.setup(world, _overview.global_position)
	world.add_child(_focus)
	_heroes.hero_requested.connect(_show_card)
	for node: Node in get_tree().get_nodes_in_group("interactables"):
		var station: Interactable = node as Interactable
		if station.action != &"hero": # Hero prompts are handled by CampHeroes.
			station.interacted.connect(_on_station_interacted.bind(station))
	toast.hide()
	options_button.pressed.connect(_open_options)
	quit_button.pressed.connect(get_tree().quit)
	if GameState.character: # Back from a run: same hero as before.
		_play_as(GameState.character, true)
	else:
		_start_choosing()


func _start_choosing() -> void:
	_choosing = true
	_camera.size = CHOOSE_ZOOM
	hint_label.text = tr("UI_CHOOSE_HERO")
	_show_card(SaveManager.get_character())
	_camera.set_target(_focus, true)


## You now play this hero: control, camera and save follow.
func _play_as(character: CharacterData, snap: bool) -> void:
	var hero: Player = _heroes.control(character)
	SaveManager.select_character(character)
	GameState.character = character
	_camera.set_target(hero, snap)
	if _choosing:
		_choosing = false
		create_tween().tween_property(_camera, "size", _play_zoom, ZOOM_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hint_label.text = tr("UI_HUB_HINT") % [InputHints.key_for("interact"), InputHints.key_for("camera_toggle"), InputHints.key_for("pause")]
	if SaveManager.profile["stats"]["runs_played"] == 0: # Point new players to the tutorial.
		hint_label.text += "\n" + tr("UI_HUB_HINT_NEW")


## Opens (or updates) the hero card, on the side away from the hero's area.
func _show_card(character: CharacterData) -> void:
	if _open_panel and not _open_panel is HeroCard:
		return
	if _open_panel == null:
		var card: HeroCard = HERO_CARD.instantiate()
		_open(card)
		card.confirmed.connect(_on_hero_confirmed)
		card.closed.connect(_close_panel)
		card.browse.connect(_browse)
	_card_character = character
	var on_right: bool = _heroes.area_of(character).card_on_right()
	(_open_panel as HeroCard).show_character(character, on_right, _choosing)
	if _choosing:
		# Frame the hero on the side away from the card (the camera glides there).
		var screen_right: Vector3 = _camera.global_basis.x
		screen_right.y = 0.0
		var shift: float = CHOOSE_SHIFT if on_right else -CHOOSE_SHIFT
		_focus.global_position = _heroes.hero_of(character).global_position + screen_right.normalized() * shift


func _browse(step: int) -> void:
	var list: Array[CharacterData] = _heroes.characters()
	_show_card(list[wrapi(list.find(_card_character) + step, 0, list.size())])


func _on_hero_confirmed(character: CharacterData) -> void:
	_close_panel()
	_play_as(character, false)


# Clicks that no UI took land here: pick a hero in the 3D camp.
func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var character: CharacterData = _hero_under_mouse()
		if character and _heroes.hero_of(character) != _heroes.controlled:
			_show_card(character)


func _hero_under_mouse() -> CharacterData:
	var pos: Vector2 = retro_screen.to_game_position(retro_screen.get_local_mouse_position())
	var from: Vector3 = _camera.project_ray_origin(pos)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, from + _camera.project_ray_normal(pos) * 200.0, PLAYER_LAYER)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)
	return _heroes.character_of(hit["collider"]) if not hit.is_empty() else null


func _on_station_interacted(_by: Player, station: Interactable) -> void:
	if _open_panel:
		return
	match station.action:
		&"missions":
			_open(MISSION_BOARD_PANEL.instantiate())
		&"stash":
			_open(STASH_PANEL.instantiate())
		&"crafting":
			_open(FORGE_PANEL.instantiate())
		&"loadout":
			_open(LOADOUT_PANEL.instantiate())
		&"skills":
			_open(SHRINE_PANEL.instantiate())
		&"tutorial":
			_open(TUTORIAL_PROMPT.instantiate())
		_:
			_show_toast(tr("UI_COMING_SOON") % tr(station.prompt_key))


# Esc / Start with nothing else open. An open panel handles its own Esc before this runs.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_open_options()


func _open_options() -> void:
	if _open_panel == null:
		_open(OPTIONS_PANEL.instantiate())


## Panels emit `closed`. While one is open the hero can't move or interact.
func _open(panel: Control) -> void:
	_open_panel = panel
	options_button.disabled = true
	if panel.has_signal("closed") and not panel is HeroCard:
		panel.connect("closed", _close_panel)
	panel_host.add_child(panel)
	if _heroes.controlled:
		_heroes.controlled.input.enabled = false


func _close_panel() -> void:
	_open_panel.queue_free()
	_open_panel = null
	options_button.disabled = false
	# Wait a frame so the button press that closed the panel doesn't also reach the hero.
	await get_tree().process_frame
	if _heroes.controlled and _open_panel == null:
		_heroes.controlled.input.enabled = true


func _show_toast(text: String) -> void:
	toast.text = text
	toast.show()
	toast.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_interval(TOAST_TIME)
	tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	tween.tween_callback(toast.hide)
