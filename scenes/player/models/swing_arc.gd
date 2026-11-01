class_name SwingArc
extends RefCounted
## The crescent a melee swing leaves in the air, tinted by the weapon. Same reach as the swing's hitbox.

const INNER: float = 0.55
const OUTER: float = 1.75
const HALF_ANGLE: float = 1.25 ## Radians to each side of straight ahead.
const SEGMENTS: int = 10


static func make_mesh() -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	for i: int in SEGMENTS:
		var a: float = lerpf(-HALF_ANGLE, HALF_ANGLE, float(i) / SEGMENTS)
		var b: float = lerpf(-HALF_ANGLE, HALF_ANGLE, float(i + 1) / SEGMENTS)
		# Thin at both tips, widest in the middle, so it reads as a blade's path.
		var inner_a: float = lerpf(OUTER, INNER, sin(float(i) / SEGMENTS * PI))
		var inner_b: float = lerpf(OUTER, INNER, sin(float(i + 1) / SEGMENTS * PI))
		var outer_a: Vector3 = _point(a, OUTER)
		var outer_b: Vector3 = _point(b, OUTER)
		var in_a: Vector3 = _point(a, inner_a)
		var in_b: Vector3 = _point(b, inner_b)
		for vertex: Vector3 in [outer_a, in_a, outer_b, outer_b, in_a, in_b]:
			tool.add_vertex(vertex)
	return tool.commit()


static func make_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color.lightened(0.35), 0.75)
	return material


static func _point(angle: float, radius: float) -> Vector3:
	return Vector3(sin(angle) * radius, 0.0, -cos(angle) * radius)
