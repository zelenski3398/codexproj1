class_name WartimeChurch
extends Node3D

const STONE := Color("bdaa8b")
const TRIM := Color("d4c1a0")
const SHADOW := Color("4d4236")
const SILHOUETTE_RANGE := 7600.0
const DETAIL_RANGE := 620.0
var record: Dictionary
var foundation_depth: float
var _palette: Dictionary = {}
var _building_parts: Array[MeshInstance3D] = []


func _ready() -> void:
	name = "Church_" + String(record.id)
	var width := float(record.size[0])
	var length := float(record.size[1])
	var profile: Array = record.profile
	var details: Dictionary = record.get("details", {})
	var nave_height := float(profile[0])
	var transept := float(profile[1])
	var tower_count := int(profile[2])
	var tower_rise := float(profile[3])
	var dome_rise := float(profile[4])
	var facade := int(profile[5])
	var nave_width := width * (.88 if transept == 0 else .62)
	var nave_length := length * .91
	var front := nave_length * .5
	_solid(Vector3(nave_width, nave_height + foundation_depth, nave_length),
		Vector3(0, (nave_height - foundation_depth) * .5, 0), STONE)
	_box(Vector3(nave_width + .65, .48, nave_length + .6), Vector3(0, nave_height, 0), TRIM)
	if transept > 0:
		var wing_length := length * transept
		var wing_height := nave_height * .80
		_solid(Vector3(width * .92, wing_height + foundation_depth, wing_length),
			Vector3(0, (wing_height - foundation_depth) * .5, -length * .11), STONE.darkened(.035))
		_box(Vector3(width * .95, .42, wing_length + .28), Vector3(0, wing_height, -length * .11), TRIM)
	if dome_rise > 0:
		var tint := Color(details.get("dome_tint", "9e8975"))
		_dome(nave_width * .34, nave_height, Vector2(0, -length * .13), dome_rise, int(details.get("dome_sides", 16)), tint)
		if details.get("satellite_domes", false):
			for side in [-1.0, 1.0]:
				_dome(nave_width * .17, nave_height * .80, Vector2(side * width * .34, -length * .11), dome_rise * .38, 8, tint)
	_facade(nave_width, nave_height, front, facade, bool(record.minor))
	var tower_width := clampf(width * .16, 2.3, 5.8)
	for index in tower_count:
		var side := -1.0 if index == 0 else 1.0
		if tower_count == 1:
			side = float(details.get("tower_side", -1))
		var tower_x := side * (width - tower_width) * .5
		_tower(Vector3(tower_x, 0, front - tower_width * .57), tower_width, nave_height + tower_rise, facade)
	if details.get("facade_clock", false):
		var clock := CylinderMesh.new()
		clock.top_radius = clampf(width * .031, .45, .9)
		clock.bottom_radius = clock.top_radius
		clock.height = .13
		clock.radial_segments = 16
		var dial := _mesh(clock, Vector3(0, nave_height * .92, front + .24), Color("e3d4b8"), true)
		dial.rotation.x = PI / 2
		_box(Vector3(.055, clock.top_radius * 1.05, .05), Vector3(0, nave_height * .94, front + .32), SHADOW, true)
	if tower_count == 0:
		_bell_cot(nave_height, front, facade)
	for side in [-1.0, 1.0]:
		for slot in [-1.0, 0.0, 1.0]:
			var opening := _arch(.9, 1.8, Vector3(side * (nave_width * .5 + .025), nave_height * .64, slot * length * .21), SHADOW, true)
			opening.rotation.y = side * PI / 2
	_merge_church_meshes()


func _facade(width: float, height: float, front: float, style: int, chapel: bool) -> void:
	var pediment_width := width * (.67 if style == 1 else .90)
	var cornice := height * .78
	_box(Vector3(width + .38, .55, .58), Vector3(0, cornice, front + .12), TRIM)
	var gate_width := clampf(width * .14, 1.05, 2.75)
	var gate_height := clampf(height * .36, 2.3, 5.1)
	_arch(gate_width + .37, gate_height + .21, Vector3(0, .12, front + .035), TRIM, false)
	_arch(gate_width, gate_height, Vector3(0, .18, front + .06), SHADOW, false)
	var order := 2 if chapel else (6 if style == 4 else 4)
	for index in order:
		var x := lerpf(-pediment_width * .50, pediment_width * .50, float(index) / (order - 1))
		var projection := 1.20 if style >= 3 else .25
		var column_width := clampf(width * .044, .20, .82)
		_box(Vector3(column_width, cornice - .6, projection), Vector3(x, cornice * .5, front + projection * .36), TRIM)
		_box(Vector3(column_width * 1.32, .29, projection + .30), Vector3(x, .62, front + projection * .36), TRIM, true)
		_box(Vector3(column_width * 1.34, .29, projection + .30), Vector3(x, cornice - .4, front + projection * .36), TRIM, true)
	var rise := height * (.24 if style >= 2 else .13)
	_pediment(pediment_width, rise, Vector3(0, height - .30, front + .22), TRIM)
	_arch(gate_width * .57, gate_height * .41, Vector3(0, cornice + .55, front + .039), SHADOW, true)
	if not chapel:
		for side in [-1.0, 1.0]:
			_arch(gate_width * .58, gate_height * .63, Vector3(side * width * .29, .21, front + .04), SHADOW, true)
	for step in range(1, 5 if style == 4 else 3):
		_box(Vector3(gate_width * (2.5 if chapel else 3.7) + step * .22, .22, .54),
			Vector3(0, .14 - step * .08, front + step * .43), TRIM, true)


func _tower(base: Vector3, width: float, height: float, style: int) -> void:
	_solid(Vector3(width, height + foundation_depth, width),
		base + Vector3(0, (height - foundation_depth) * .5, 0), STONE)
	for band in [.42, .73, .96]:
		_box(Vector3(width * 1.14, .42, width * 1.14), base + Vector3(0, height * band, 0), TRIM)
	_arch(width * .49, width * .87, base + Vector3(0, height - width * 1.15, width * .505), SHADOW, true)
	var cap := 1.35 if style >= 3 else .74
	_column(width * .52, width * .17, width * cap, base + Vector3(0, height + width * cap * .5, 0), TRIM, 8)
	_box(Vector3(.18, width * .39, .18), base + Vector3(0, height + width * (cap + .15), 0), SHADOW, true)


func _bell_cot(height: float, front: float, style: int) -> void:
	var width := 1.45 if style == 1 else 1.9
	_box(Vector3(width, 1.44, .75), Vector3(0, height + .73, front - .42), STONE)
	_arch(width * .43, .94, Vector3(0, height + .28, front - .035), SHADOW, false)
	_pediment(width * 1.14, .62, Vector3(0, height + 1.43, front - .44), TRIM)


func _dome(radius: float, base: float, center: Vector2, rise: float, sides: int, tint: Color) -> void:
	var drum := rise * .38
	var x := center.x
	var z := center.y
	_column(radius, radius, drum, Vector3(x, base + drum * .5, z), STONE, sides)
	_column(radius * 1.06, radius * 1.06, .34, Vector3(x, base + drum, z), TRIM, sides)
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.is_hemisphere = true
	mesh.radial_segments = maxi(12, sides)
	mesh.rings = 8
	var cap := _mesh(mesh, Vector3(x, base + drum, z), tint)
	cap.scale = Vector3(radius, rise - drum, radius)
	_column(radius * .22, radius * .23, rise * .29, Vector3(x, base + rise * 1.12, z), TRIM, 8)
	_column(radius * .29, radius * .07, rise * .20, Vector3(x, base + rise * 1.36, z), STONE.darkened(.21), 8)
	for index in 8:
		var angle := TAU * index / 8.0
		var p := Vector3(x + sin(angle) * radius * .99, base + drum * .23, z + cos(angle) * radius * .99)
		var opening := _arch(radius * .22, drum * .54, p, SHADOW, true)
		opening.rotation.y = angle


func _arch(width: float, height: float, base: Vector3, tint: Color, detail: bool) -> MeshInstance3D:
	var points := PackedVector3Array([Vector3.ZERO, Vector3(-width * .5, 0, 0), Vector3(width * .5, 0, 0)])
	var roof := minf(width * .5, height * .4)
	for i in 9:
		var angle := PI * i / 8
		points.append(Vector3(cos(angle) * width * .5, height - roof + sin(angle) * roof, 0))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(2, points.size()):
		for vertex in [points[0], points[i], points[1 if i == points.size() - 1 else i + 1]]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	return _mesh(surface.commit(), base, tint, detail)


func _pediment(width: float, height: float, center: Vector3, tint: Color) -> void:
	var prism := PrismMesh.new()
	prism.size = Vector3(width, height, .70)
	_mesh(prism, center + Vector3.UP * height * .5, tint)


func _column(bottom: float, top: float, height: float, center: Vector3, tint: Color, segments: int) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.bottom_radius = bottom
	cylinder.top_radius = top
	cylinder.height = height
	cylinder.radial_segments = segments
	cylinder.rings = 1
	_mesh(cylinder, center, tint)


func _solid(size: Vector3, center: Vector3, tint: Color) -> void:
	_box(size, center, tint)
	var collision := StaticBody3D.new()
	collision.position = center
	collision.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	collision.add_child(shape)
	add_child(collision)


func _box(size: Vector3, center: Vector3, tint: Color, detail := false) -> void:
	var box := BoxMesh.new()
	box.size = size
	_mesh(box, center, tint, detail)


func _mesh(mesh: Mesh, center: Vector3, tint: Color, detail := false) -> MeshInstance3D:
	if not _palette.has(tint):
		var material := MeshKit.material(tint)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_palette[tint] = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	instance.material_override = _palette[tint]
	instance.visibility_range_end = DETAIL_RANGE if detail else SILHOUETTE_RANGE
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_building_parts.append(instance)
	return instance

func _merge_church_meshes() -> void:
	# Bake the repeated limestone and trim primitives into a few surfaces.
	# Keep entrances and windows on a separate mesh with a shorter range.
	for cutoff in [DETAIL_RANGE, SILHOUETTE_RANGE]:
		var groups: Dictionary = {}
		for part in _building_parts:
			if part.visibility_range_end != cutoff:
				continue
			var material := part.material_override
			if not groups.has(material):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tool.set_material(material)
				groups[material] = tool
			groups[material].append_from(part.mesh, 0, part.transform)
		var mesh := ArrayMesh.new()
		for tool in groups.values():
			tool.commit(mesh)
		var result := MeshInstance3D.new()
		result.mesh = mesh
		result.visibility_range_end = cutoff
		result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(result)
	for part in _building_parts:
		part.free()
	_building_parts.clear()
