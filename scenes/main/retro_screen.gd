class_name RetroScreen
extends Control
## The retro look, reusable by every 3D screen (camp, runs): renders a 3D world into a
## low-res SubViewport and shows it scaled up with nearest-neighbor filtering.
## Put UI in a CanvasLayer next to this so it stays full-resolution.
## The render size follows the window so every game pixel covers a whole number of screen
## pixels: uneven scaling is what makes nearest-neighbor look blurry and shimmery.

const ASPECT: float = 16.0 / 9.0

## Sharpness: the world is rendered at least this many lines tall. Lower = chunkier pixels.
@export var min_render_height: int = 270

var render_size: Vector2i = Vector2i(960, 540)

@onready var game_viewport: SubViewport = $GameViewport
@onready var screen: TextureRect = $Screen


func _ready() -> void:
	screen.texture = game_viewport.get_texture()
	get_window().size_changed.connect(_fit_render_size)
	_fit_render_size()


# E.g. 720p window: 1280x720 (x1). 1080p: 960x540 (x2). 1440p: 1280x720 (x2). 4K: 960x540 (x4).
func _fit_render_size() -> void:
	var window: Vector2 = Vector2(get_window().size) # Real pixels, not stretched UI units.
	var shown_height: float = minf(window.y, window.x / ASPECT)
	var pixel_scale: int = maxi(floori(shown_height / min_render_height), 1)
	render_size = Vector2i(roundi(shown_height * ASPECT / pixel_scale), roundi(shown_height / pixel_scale))
	game_viewport.size = render_size


## Puts a 3D world (a map scene) inside the low-res viewport.
func add_world(world: Node) -> void:
	game_viewport.add_child(world)


# A plain SubViewport gets no input on its own. Forward mouse motion, converted from
# window pixels to low-res game pixels, so mouse aiming works inside the game world.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var local_event: InputEventMouseMotion = event.duplicate()
		local_event.position = to_game_position(get_local_mouse_position())
		game_viewport.push_input(local_event, true)


# The camera lives inside the SubViewport, where key presses don't reach, so its switch is caught here.
# Skipped while paused: this node pauses with the game. Menus take the key first if they use it.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_toggle"):
		Settings.toggle_camera_mode()


## Window pixels (local to this control) -> low-res game pixels, e.g. for clicking on 3D things.
func to_game_position(screen_pos: Vector2) -> Vector2:
	var render: Vector2 = Vector2(render_size)
	var scale_factor: float = minf(size.x / render.x, size.y / render.y)
	var offset: Vector2 = (size - render * scale_factor) * 0.5
	return (screen_pos - offset) / scale_factor
