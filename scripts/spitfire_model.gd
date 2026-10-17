class_name SpitfireModel
extends Node3D
## Recognisable, original mesh placeholder: elliptical wings, tapered fuselage,
## framed early canopy, RAF roundels, fin, tailplane, propeller and three wheels.
var reference_finish: bool = false
var engine_factors: Dictionary = {}
var propeller: Node3D
var wheel_roots: Array[Node3D] = []
var struts: Array[MeshInstance3D] = []
var gun_ports: Array[Marker3D] = []
var green := MeshKit.material(Color("505b40"))
var brown := MeshKit.material(Color("655442"))
var underside := MeshKit.material(Color("9caeaa"))
var rubber := MeshKit.material(Color("222729"))
var metal := MeshKit.material(Color("b3bab4"), 0.4)

func _ready() -> void:
	reference_finish = true
	green = MeshKit.material(Color("4c5547"), 0.48)
	green.metallic = 0.18
	brown = MeshKit.material(Color("424849"), 0.52)
	underside = MeshKit.material(Color("a3afa0"), 0.57)
	_fuselage()
	_wing(5.6, 2.35, -0.35, -0.1, green)
	_wing(2.05, 1.25, 3.55, 0.05, green)
	# Four ports on each wing, on the actual elliptical leading edge. All
	# weapon origins use these markers; none fire from the nose/propeller.
	for side in [-1.0, 1.0]:
		for distance in [2.25, 2.7, 3.15, 3.6]:
			var t: float = distance / 5.6
			var leading_z := -0.35 + t * 0.45 - 2.35 * sqrt(1.0 - t * t) * 0.5
			var port := Marker3D.new()
			port.name = "GunPort%d" % gun_ports.size()
			port.position = Vector3(side * distance, -0.1 + t * 0.12, leading_z - 0.08)
			add_child(port)
			gun_ports.append(port)
			var barrel := MeshKit.cylinder(port, 0.06, 0.14, Vector3.ZERO, rubber)
			barrel.rotation.x = PI / 2.0
	# Camouflage patches follow the main wing's curved silhouette.
	for side in [-1.0, 1.0]:
		_roundel(Vector3(side * 3.8, 0.035, -0.1), 0.54, false)
		_roundel(Vector3(side * 0.37, 0.1, 1.55), 0.38, true)
	var canopy := MeshKit.material(Color(0.32, 0.5, 0.58, 0.18), 0.12)
	canopy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	canopy.cull_mode = BaseMaterial3D.CULL_DISABLED
	canopy.metallic = 0.32
	MeshKit.sphere(self, Vector3(0.83, 1.04, 1.65), Vector3(0.0, 0.60, 0.18), canopy)
	MeshKit.rod(self, Vector3(-0.39, 0.45, -0.32), Vector3(0.39, 0.45, -0.32), 0.045, green)
	MeshKit.rod(self, Vector3(0.0, 1.03, -0.55), Vector3(0.0, 1.03, 0.5), 0.035, green)
	MeshKit.box(self, Vector3(0.13, 1.1, 1.0), Vector3(0.0, 0.55, 3.82), green).rotation.x = -0.2
	MeshKit.sphere(self, Vector3(0.16, 0.8, 1.0), Vector3(0.0, 1.05, 3.74), green)
	# Fin flash: original RAF red / white / blue rectangles.
	for side in [-1.0, 1.0]:
		for i in range(3):
			MeshKit.box(self, Vector3(0.015, 0.5, 0.17), Vector3(side * 0.09, 0.82, 3.52 + i * 0.17), MeshKit.material([Color("933d32"), Color("e5e4cf"), Color("263951")][i]))
	MeshKit.box(self, Vector3(0.9, 0.28, 0.9), Vector3(1.55, -0.33, 0.05), underside)
	MeshKit.box(self, Vector3(0.7, 0.22, 0.65), Vector3(-1.55, -0.3, 0.0), underside)
	for side in [-1.0, 1.0]:
		for i in range(6):
			MeshKit.box(self, Vector3(0.14, 0.11, 0.22), Vector3(side * 0.5, 0.16, -2.5 + i * 0.25), rubber)
	propeller = Node3D.new()
	propeller.position = Vector3(0.0, 0.0, -3.83)
	add_child(propeller)
	MeshKit.sphere(propeller, Vector3(0.69, 0.69, 0.8), Vector3(0.0, 0.0, -0.23), underside)
	for i in range(3):
		var blade := Node3D.new()
		blade.rotation.z = TAU * i / 3.0
		propeller.add_child(blade)
		MeshKit.box(blade, Vector3(0.16, 1.2, 0.055), Vector3(0.0, 0.77, 0.0), rubber)
		MeshKit.box(blade, Vector3(0.17, 0.16, 0.06), Vector3(0.0, 1.32, 0.0), MeshKit.material(Color("d5b65f")))
	for i in range(3):
		var root := Node3D.new()
		add_child(root)
		wheel_roots.append(root)
		var radius := 0.32 if i < 2 else 0.18
		var tyre := MeshKit.cylinder(root, radius, 0.19 if i < 2 else 0.12, Vector3.ZERO, rubber)
		tyre.rotation.z = PI / 2.0
		var hub := MeshKit.cylinder(root, radius * 0.45, 0.2 if i < 2 else 0.13, Vector3.ZERO, metal)
		hub.rotation.z = PI / 2.0
		struts.append(MeshKit.cylinder(self, 0.055, 0.5, Vector3.ZERO, metal))
	build_pilot_station(0.25, 0.10)
	_reference_details()

func build_pilot_station(cockpit_z: float, hip_height: float) -> void:
	# Visual seat, stick, throttle and pedals. No physics/collision changes.
	var seat: StandardMaterial3D = MeshKit.material(Color("414a42"))
	MeshKit.box(self, Vector3(0.37, 0.045, 0.36), Vector3(0, hip_height - 0.035, cockpit_z), seat)
	MeshKit.box(self, Vector3(0.37, 0.44, 0.045), Vector3(0, hip_height + 0.20, cockpit_z + 0.18), seat)
	MeshKit.rod(self, Vector3(0, hip_height - 0.35, cockpit_z - 0.58), Vector3(-0.10, hip_height + 0.31, cockpit_z - 0.58), 0.013, metal)
	MeshKit.sphere(self, Vector3(0.045, 0.085, 0.045), Vector3(-0.10, hip_height + 0.31, cockpit_z - 0.58), rubber)
	MeshKit.box(self, Vector3(0.04, 0.07, 0.065), Vector3(0.21, hip_height + 0.24, cockpit_z - 0.58), rubber)
	for side in [-1.0, 1.0]:
		MeshKit.box(self, Vector3(0.095, 0.02, 0.12), Vector3(side * 0.11, hip_height - 0.575, cockpit_z - 0.5), metal)

func _fuselage() -> void:
	var rings: Array[Vector3] = [Vector3(-3.75, 0.29, 0.3), Vector3(-3.1, 0.48, 0.5), Vector3(-1.8, 0.52, 0.6), Vector3(-0.72, 0.496, 0.582), Vector3(0.0, 0.48, 0.57), Vector3(1.05, 0.3947, 0.4584), Vector3(1.6, 0.35, 0.4), Vector3(3.1, 0.17, 0.23), Vector3(4.3, 0.065, 0.09)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(rings.size() - 1):
		for i in range(20):
			var a := TAU * i / 20.0
			var b := TAU * (i + 1) / 20.0
			var r := rings[j]
			var s := rings[j + 1]
			# Visual cockpit opening only: physics hull/contact shapes stay intact.
			if r.x >= -0.72 and s.x <= 1.05 and sin((a + b) * 0.5) > 0.3:
				continue
			var points := [Vector3(cos(a) * r.y, sin(a) * r.z, r.x), Vector3(cos(b) * r.y, sin(b) * r.z, r.x), Vector3(cos(a) * s.y, sin(a) * s.z, s.x), Vector3(cos(b) * s.y, sin(b) * s.z, s.x)]
			for index in [0, 2, 1, 1, 2, 3]:
				if reference_finish:
					var p: Vector3 = points[index]
					var c := underside.albedo_color if p.y < -0.25 else (brown.albedo_color if sin(p.z * 2.2 + p.x * 5) > 0.25 else green.albedo_color)
					surface.set_color(c)
				surface.add_vertex(points[index])
	surface.generate_normals()
	var mat := green.duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if reference_finish:
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.albedo_color = Color.WHITE
	MeshKit.mesh(self, _paint_mesh(surface.commit()) if reference_finish else surface.commit(), null if reference_finish else mat)
	MeshKit.sphere(self, Vector3(0.97, 0.16, 5.8), Vector3(0.0, -0.41, -0.28), underside)

func _wing(span: float, chord: float, z: float, y: float, mat: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		for i in range(24):
			var t0 := float(i) / 24.0
			var t1 := float(i + 1) / 24.0
			var c0 := chord * sqrt(1.0 - t0 * t0)
			var c1 := chord * sqrt(1.0 - t1 * t1)
			var center0 := z + t0 * 0.45
			var center1 := z + t1 * 0.45
			var vertices := [Vector3(side * span * t0, y + t0 * 0.12, center0 - c0 * 0.5), Vector3(side * span * t0, y + t0 * 0.12, center0 + c0 * 0.5), Vector3(side * span * t1, y + t1 * 0.12, center1 - c1 * 0.5), Vector3(side * span * t1, y + t1 * 0.12, center1 + c1 * 0.5)]
			for index in ([0, 2, 1, 1, 2, 3] if side > 0 else [0, 1, 2, 1, 3, 2]):
				if reference_finish:
					var p: Vector3 = vertices[index]
					surface.set_color(brown.albedo_color if sin(p.x * 1.8 + p.z * 4) > 0.15 else green.albedo_color)
				surface.add_vertex(vertices[index])
			if reference_finish:
				for index in ([0, 1, 2, 1, 3, 2] if side > 0 else [0, 2, 1, 1, 2, 3]):
					surface.set_color(underside.albedo_color)
					surface.add_vertex(vertices[index] + Vector3.DOWN * 0.065)
	surface.generate_normals()
	var wing_mat := mat.duplicate() as StandardMaterial3D
	wing_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if reference_finish:
		wing_mat.vertex_color_use_as_albedo = true
		wing_mat.vertex_color_is_srgb = true
		wing_mat.albedo_color = Color.WHITE
	MeshKit.mesh(self, _paint_mesh(surface.commit(), true) if reference_finish else surface.commit(), null if reference_finish else wing_mat)

func _paint_mesh(source: ArrayMesh, wing: bool = false) -> ArrayMesh:
	# Explicit StandardMaterial surfaces give local GL and web the same paint,
	# including fragments; no runtime texture or vertex-colour interpretation.
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var builders: Dictionary = {}
	for i in range(0, vertices.size(), 3):
		var color: Color = colors[i]
		if not builders.has(color):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			builders[color] = tool
		for j in range(3):
			builders[color].add_vertex(vertices[i + j])
	var result := ArrayMesh.new()
	for color in builders:
		builders[color].generate_normals()
		builders[color].commit(result)
		var paint := MeshKit.material(color.darkened(0.45) if wing and color.g < 0.5 else color, 0.55)
		paint.cull_mode = BaseMaterial3D.CULL_BACK if wing else BaseMaterial3D.CULL_DISABLED
		result.surface_set_material(result.get_surface_count() - 1, paint)
	return result

func _roundel(pos: Vector3, radius: float, side: bool) -> void:
	var colors: Array = [Color("22384f"), Color("e8e3c9"), Color("9e3c31")]
	var sizes: Array = [1.0, 0.67, 0.32]
	if reference_finish:
		colors = [Color("d7b150"), Color("172e4a"), Color("e3decb"), Color("ad3b26")] if side else [Color("172e4a"), Color("b83d25")]
		sizes = [1.0, 0.88, 0.57, 0.29] if side else [1.0, 0.36]
	for i in range(colors.size()):
		var disc := MeshKit.cylinder(self, radius * sizes[i], 0.006, pos, MeshKit.material(colors[i]))
		if side:
			disc.rotation.z = PI / 2.0
			disc.position.x += signf(pos.x) * float(i) * 0.007
		else:
			disc.position.y += i * 0.007

func _reference_details() -> void:
	# Original reference-inspired markings; these are geometry, not photo decals.
	var seam := MeshKit.material(Color("333b36"), 0.7)
	var yellow := MeshKit.material(Color("c7a74d"), 0.65)
	for side in [-1.0, 1.0]:
		# Early framed sliding canopy and windscreen, preserving the pilot opening.
		for z in [-0.43, 0.15, 0.73]:
			MeshKit.rod(self, Vector3(side * 0.36, 0.49, z), Vector3(side * 0.27, 0.96, z), 0.018, green)
			MeshKit.rod(self, Vector3(side * 0.27, 0.96, z), Vector3(0, 1.1, z), 0.018, green)
		MeshKit.rod(self, Vector3(side * 0.29, 0.88, -0.45), Vector3(side * 0.29, 0.88, 0.76), 0.015, green)
		# Wing panel/aileron lines follow the elliptical planform.
		for x in [1.8, 2.7, 3.6, 4.4]:
			var t: float = x / 5.6
			var chord: float = 2.35 * sqrt(1 - t * t)
			var center: float = -0.35 + t * 0.45
			MeshKit.rod(self, Vector3(side * x, -0.09 + t * 0.12, center - chord * 0.46), Vector3(side * x, -0.09 + t * 0.12, center + chord * 0.46), 0.006, seam)
		for i in range(15):
			var t0: float = 0.5 + i * 0.027
			var t1: float = t0 + 0.027
			var a := Vector3(side * 5.6 * t0, -0.085 + t0 * 0.12, -0.35 + t0 * 0.45 - 1.175 * sqrt(1 - t0 * t0))
			var b := Vector3(side * 5.6 * t1, -0.085 + t1 * 0.12, -0.35 + t1 * 0.45 - 1.175 * sqrt(1 - t1 * t1))
			MeshKit.rod(self, a, b, 0.025, yellow)
		MeshKit.rod(self, Vector3(side * 2.9, 0.02, 0.49), Vector3(side * 4.6, 0.04, 0.49), 0.008, seam)
		for z in [-3.05, -2.65, -1.3]:
			MeshKit.rod(self, Vector3(side * 0.491, -0.23, z), Vector3(side * 0.491, 0.3, z), 0.007, seam)
		for data in [["AL", 0.75, 0.42], ["K", 2.15, 0.42], ["P7308", 2.72, 0.12]]:
			var label := Label3D.new()
			label.text = data[0]
			label.font_size = 64
			label.pixel_size = data[2] / 64.0
			label.modulate = Color("ded9b6") if data[0] != "P7308" else Color("262b28")
			label.outline_size = 0
			label.no_depth_test = false
			label.position = Vector3(side * (0.48 if data[1] < 1 else 0.30), 0.10, data[1])
			label.rotation.y = side * PI / 2
			add_child(label)
	MeshKit.rod(self, Vector3(0, 0.56, 1.08), Vector3(0, 1.47, 1.25), 0.025, green)
	MeshKit.rod(self, Vector3(0, 1.47, 1.25), Vector3(0, 1.38, 3.75), 0.004, seam)

func animate(delta: float, throttle: float, gear: LandingGear, broken: bool) -> void:
	if not broken:
		propeller.rotation.z += delta * (3.0 + throttle * 95.0) * float(engine_factors.get(0, 1))
	for i in range(3):
		wheel_roots[i].visible = gear.extended
		struts[i].visible = gear.extended
		var length := gear.travel[i] - gear.compression[i]
		wheel_roots[i].position = gear.anchors[i] + Vector3.DOWN * length
		struts[i].position = gear.anchors[i] + Vector3.DOWN * length * 0.5
		struts[i].scale.y = length / 0.5

