class_name SkillFx
extends RefCounted
## Skill visuals built in code: particle trails and bursts, impact rings, swing arcs. Purely visual:
## nothing here touches gameplay, and color is only a hint (menus and the HUD name the element).
## CPU particles, in small numbers, so the first cast never hitches while a shader compiles.

const ARCANE: int = -1 ## Not an element: the look of plain magic bolts.
const TRAIL_PARTICLES: float = 26.0
const RING_TIME: float = 0.18
const ARC_TIME: float = 0.16
const ARC_TILT: float = 0.5
const ARC_ROLL: float = 0.4
const WARM_UP_DEPTH: float = 0.6 ## Below the floor: drawn, so its shaders compile, but never seen.


## Draws every effect once, out of sight, when a mission starts. Otherwise the first cast freezes the
## game for a moment while its shaders compile.
static func warm_up(world: Node, point: Vector3) -> void:
	var hidden: Vector3 = point + Vector3.DOWN * WARM_UP_DEPTH
	burst(world, hidden, Element.Type.FIRE, 0.2)
	impact(world, hidden, 0.0, Element.Type.ICE, Color.WHITE, 0.2)
	arc(world, hidden, 0.0, Color.WHITE, 0.2)
	var trail: CPUParticles3D = make_trail(ARCANE, 0.2)
	world.add_child(trail)
	trail.global_position = hidden
	world.get_tree().create_timer(0.1, false, true).timeout.connect(trail.queue_free)


## The main color of an element, or of ARCANE.
static func color_of(element: int) -> Color:
	match element:
		Element.Type.FIRE:
			return Color(1.0, 0.55, 0.15)
		Element.Type.ICE:
			return Color(0.6, 0.88, 1.0)
		Element.Type.POISON:
			return Color(0.55, 0.9, 0.35)
		ARCANE:
			return Color(0.8, 0.6, 1.0)
	return Color(0.95, 0.92, 0.85)


## A stream of particles that stays behind a moving projectile. Add it as a child.
static func make_trail(element: int, size: float = 1.0) -> CPUParticles3D:
	# More particles rather than bigger ones: a big spell gets a thick stream of fine sparks.
	var trail: CPUParticles3D = _make_particles(element, sqrt(size))
	trail.amount = roundi(TRAIL_PARTICLES * size)
	trail.lifetime = 0.55
	trail.local_coords = false
	trail.spread = 180.0
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.2 * size
	trail.initial_velocity_min = 0.3
	trail.initial_velocity_max = 1.4
	return trail


## Lets a trail's last particles finish after its projectile is gone.
static func release_trail(trail: CPUParticles3D, world: Node) -> void:
	if trail == null or not is_instance_valid(world):
		return
	trail.reparent(world)
	trail.emitting = false
	world.get_tree().create_timer(trail.lifetime, false, true).timeout.connect(trail.queue_free)


## A one-shot spray of particles.
static func burst(world: Node, point: Vector3, element: int, size: float = 1.0) -> void:
	var particles: CPUParticles3D = _make_particles(element, size)
	particles.amount = 14
	particles.lifetime = 0.45
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.local_coords = false
	particles.spread = 180.0
	particles.initial_velocity_min = 1.5 * size
	particles.initial_velocity_max = 4.0 * size
	world.add_child(particles)
	particles.global_position = point
	particles.emitting = true
	world.get_tree().create_timer(particles.lifetime + 0.1, false, true).timeout.connect(particles.queue_free)


## Where a strike lands: a small upright ring that opens and fades, plus a spray.
static func impact(world: Node, point: Vector3, yaw: float, element: int, tint: Color, size: float = 1.0) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = 0.34
	mesh.outer_radius = 0.42
	mesh.rings = 12
	mesh.ring_segments = 4
	ring.mesh = mesh
	var material: StandardMaterial3D = _flat_material(tint)
	material.no_depth_test = true # The hit lands inside the enemy's body: show it anyway.
	ring.material_override = material
	world.add_child(ring)
	ring.global_position = point
	ring.rotation = Vector3(PI / 2.0, yaw, 0.0)
	ring.scale = Vector3.ONE * 0.3 * size
	var tween: Tween = ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3.ONE * size, RING_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(ring, "transparency", 1.0, RING_TIME)
	tween.chain().tween_callback(ring.queue_free)
	burst(world, point, element, size * 0.8)


## The crescent a big weapon swing leaves in the air.
static func arc(world: Node, point: Vector3, yaw: float, tint: Color, size: float = 1.0) -> void:
	var crescent: MeshInstance3D = MeshInstance3D.new()
	crescent.mesh = SwingArc.make_mesh()
	crescent.material_override = SwingArc.make_material(tint)
	world.add_child(crescent)
	crescent.global_position = point
	crescent.rotation = Vector3(ARC_TILT, yaw, ARC_ROLL) # Slanted like a slash, so it reads from behind the hero.
	crescent.scale = Vector3.ONE * size
	var tween: Tween = crescent.create_tween()
	tween.tween_property(crescent, "transparency", 1.0, ARC_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(crescent.queue_free)


static func _make_particles(element: int, size: float) -> CPUParticles3D:
	var particles: CPUParticles3D = CPUParticles3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3.ONE * 0.09
	var material: StandardMaterial3D = _flat_material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	particles.mesh = mesh
	particles.scale_amount_min = 0.7 * size
	particles.scale_amount_max = 1.4 * size
	particles.direction = Vector3.UP
	particles.spread = 45.0
	particles.gravity = _gravity_of(element)
	particles.color_ramp = _fade_of(element)
	return particles


# Fire rises, ice falls, poison drifts, plain magic floats.
static func _gravity_of(element: int) -> Vector3:
	match element:
		Element.Type.FIRE:
			return Vector3(0.0, 2.2, 0.0)
		Element.Type.ICE:
			return Vector3(0.0, -3.0, 0.0)
		Element.Type.POISON:
			return Vector3(0.0, 0.4, 0.0)
		ARCANE:
			return Vector3.ZERO
	return Vector3(0.0, -6.0, 0.0)


static func _fade_of(element: int) -> Gradient:
	var main: Color = color_of(element)
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, main.lightened(0.5))
	gradient.set_color(1, Color(main.darkened(0.4), 0.0))
	gradient.add_point(0.35, main)
	return gradient


static func _flat_material(tint: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = tint
	return material
