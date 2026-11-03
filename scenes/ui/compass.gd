class_name Compass
extends Control
## A round compass in the HUD's top-right corner. The top of the ring is always where the camera
## looks, so it reads the same over the shoulder and in the isometric view. N/E/S/W sit on the ring
## and turn with the camera; every node in group "compass_targets" gets a marker on the rim in its
## direction, with its distance just inside. Kinds (never color alone, each has its own shape and
## symbol): BOSS = red diamond with "!" (the hunted monster), QUEST = yellow triangle with "?" (zones
## to clear, plants to gather). Objectives mark things with Compass.track(); freed nodes drop off by
## themselves. Hidden when there's nothing to point at. North = -Z, the far side of every map.

const BOSS: StringName = &"boss"
const QUEST: StringName = &"quest"
const GROUP: String = "compass_targets"
const KIND_META: StringName = &"compass_kind"

const DIAMETER: float = 170.0
const RADIUS: float = 62.0 ## The ring markers sit on.
const MARKER_SIZE: float = 9.0
const BOSS_COLOR: Color = Color(0.95, 0.25, 0.2)
const QUEST_COLOR: Color = Color(1.0, 0.85, 0.2)
const CARDINALS: Array = [["COMPASS_N", Vector3(0, 0, -1)], ["COMPASS_E", Vector3(1, 0, 0)],
	["COMPASS_S", Vector3(0, 0, 1)], ["COMPASS_W", Vector3(-1, 0, 0)]]

var _labels: Array[Rect2] = [] ## Distance labels already drawn this frame, so they don't overlap.


## Puts a marker on the compass for `node` until it's untracked or freed.
static func track(node: Node3D, kind: StringName) -> void:
	node.set_meta(KIND_META, kind)
	node.add_to_group(GROUP)


static func untrack(node: Node3D) -> void:
	if node.is_in_group(GROUP):
		node.remove_from_group(GROUP)


func _ready() -> void:
	custom_minimum_size = Vector2(DIAMETER, DIAMETER)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	visible = not get_tree().get_nodes_in_group(GROUP).is_empty()
	if visible:
		queue_redraw()


func _draw() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("players") as Node3D
	var camera: Camera3D = player.get_viewport().get_camera_3d() if player else null
	if camera == null:
		return
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	var font: Font = get_theme_default_font()
	var center: Vector2 = size * 0.5
	draw_circle(center, RADIUS + 16.0, Color(0.0, 0.0, 0.0, 0.45))
	draw_arc(center, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 1.5)
	# Which way the camera looks: a notch at the top, and the hero in the middle.
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -RADIUS - 14.0), center + Vector2(-6, -RADIUS - 6.0),
		center + Vector2(6, -RADIUS - 6.0)]), Color(1, 1, 1, 0.85))
	draw_circle(center, 3.5, Color.WHITE)
	for entry: Array in CARDINALS:
		var point: Vector2 = center + _direction(forward, entry[1]) * (RADIUS - 14.0)
		_text(font, tr(entry[0]), point, 15, Color(1, 1, 1, 0.9))
	_labels.clear()
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var target: Node3D = node as Node3D
		if target == null or not target.is_inside_tree():
			continue
		var offset: Vector3 = target.global_position - player.global_position
		offset.y = 0.0
		var dir: Vector2 = _direction(forward, offset) if offset.length() > 0.5 else Vector2.UP
		_draw_marker(font, center, dir, roundi(offset.length()), target.get_meta(KIND_META, QUEST))


## Screen direction for a world direction: straight up = where the camera looks.
func _direction(forward: Vector3, world: Vector3) -> Vector2:
	var angle: float = forward.signed_angle_to(world, Vector3.UP) # Positive = to the left.
	return Vector2(-sin(angle), -cos(angle))


func _draw_marker(font: Font, center: Vector2, dir: Vector2, metres: int, kind: StringName) -> void:
	var at: Vector2 = center + dir * RADIUS
	var boss: bool = kind == BOSS
	var s: float = MARKER_SIZE
	var shape: PackedVector2Array
	if boss: # Diamond.
		shape = PackedVector2Array([at + Vector2(0, -s), at + Vector2(s, 0), at + Vector2(0, s), at + Vector2(-s, 0)])
	else: # Triangle pointing down, like a pin.
		shape = PackedVector2Array([at + Vector2(-s, -s * 0.8), at + Vector2(s, -s * 0.8), at + Vector2(0, s)])
	draw_colored_polygon(shape, BOSS_COLOR if boss else QUEST_COLOR)
	var outline: PackedVector2Array = shape.duplicate()
	outline.append(shape[0])
	draw_polyline(outline, Color.BLACK, 1.5)
	draw_string(font, at + Vector2(-3.0, 5.0 if boss else 2.0), "!" if boss else "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.BLACK)
	# Distance just inside the ring; skipped if it would cover another one.
	var text: String = tr("COMPASS_DISTANCE") % metres
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	var label_center: Vector2 = center + dir * (RADIUS - 30.0)
	var rect: Rect2 = Rect2(label_center - text_size * 0.5, text_size)
	for other: Rect2 in _labels:
		if other.intersects(rect):
			return
	_labels.append(rect)
	_text(font, text, label_center, 12, Color.WHITE)


## Centered, outlined text.
func _text(font: Font, text: String, at: Vector2, font_size: int, color: Color) -> void:
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var origin: Vector2 = at + Vector2(-text_size.x * 0.5, font_size * 0.35)
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color.BLACK)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
