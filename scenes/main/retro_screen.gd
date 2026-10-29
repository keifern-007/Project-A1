class_name RetroScreen
extends Control
## The retro look, reusable by every 3D screen (camp, runs): renders a 3D world into a
## low-res SubViewport and shows it scaled up with nearest-neighbor filtering.
## Put UI in a CanvasLayer next to this so it stays full-resolution.

@export var render_size: Vector2i = Vector2i(640, 360)

@onready var game_viewport: SubViewport = $GameViewport
@onready var screen: TextureRect = $Screen


func _ready() -> void:
	game_viewport.size = render_size
	screen.texture = game_viewport.get_texture()


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


## Window pixels (local to this control) -> low-res game pixels, e.g. for clicking on 3D things.
func to_game_position(screen_pos: Vector2) -> Vector2:
	var render: Vector2 = Vector2(render_size)
	var scale_factor: float = minf(size.x / render.x, size.y / render.y)
	var offset: Vector2 = (size - render * scale_factor) * 0.5
	return (screen_pos - offset) / scale_factor
