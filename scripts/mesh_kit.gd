class_name MeshKit
extends RefCounted
## Small procedural asset helpers; dimensions are metres.

static func material(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	return result

static func mesh(parent: Node3D, geometry: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = geometry
	item.material_override = mat
	item.position = pos
	parent.add_child(item)
	return item

static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, mat, pos)

static func sphere(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radial_segments = 20
	shape.rings = 10
	var item := mesh(parent, shape, mat, pos)
	item.scale = size
	return item

static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 16
	return mesh(parent, shape, mat, pos)

static func rod(parent: Node3D, start: Vector3, end: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var item := cylinder(parent, radius, start.distance_to(end), (start + end) * 0.5, mat)
	var direction := (end - start).normalized()
	var axis := Vector3.UP.cross(direction)
	if axis.length_squared() > 0.0001:
		item.quaternion = Quaternion(axis.normalized(), Vector3.UP.angle_to(direction))
	elif direction.y < 0.0:
		item.rotation.x = PI
	return item

