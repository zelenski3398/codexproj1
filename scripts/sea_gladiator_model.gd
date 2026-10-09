class_name SeaGladiatorModel
extends SpitfireModel
## Original mesh approximation of the supplied Gloster Sea Gladiator references.
## Rounded stacked wings, bracing, visible radial engine and fixed taildragger.
var upper_wing: MeshInstance3D
var lower_wing: MeshInstance3D
var gear_links: Array[MeshInstance3D] = []

func _ready() -> void:
	green = MeshKit.material(Color("4c574a"))
	brown = MeshKit.material(Color("444d58"))
	underside = MeshKit.material(Color("adb2af"))
	_fuselage()
	upper_wing = _biplane_wing(5.1, 1.65, -0.55, 1.38)
	lower_wing = _biplane_wing(5.0, 1.6, 0.0, -0.12)
	# Paired outer struts, central cabane struts, and fine crossed flying wires.
	for side in [-1.0, 1.0]:
		for z in [-0.6, 0.5]:
			MeshKit.rod(self, Vector3(side * 3.55, -0.08, z), Vector3(side * 3.65, 1.44, z - 0.55), 0.045, underside)
			MeshKit.rod(self, Vector3(side * 0.4, 0.42, z - 0.2), Vector3(side * 0.9, 1.39, z - 0.45), 0.035, metal)
			MeshKit.rod(self, Vector3(side * 0.7, -0.1, z), Vector3(side * 3.65, 1.44, z - 0.55), 0.012, rubber)
			MeshKit.rod(self, Vector3(side * 0.9, 1.39, z - 0.55), Vector3(side * 3.55, -0.08, z), 0.012, rubber)
		_raf_roundel(Vector3(side * 3.85, 1.46, -0.45), 0.53, false, false)
		_raf_roundel(Vector3(side * 0.41, 0.0, 1.05), 0.30, true, true)
		var letters: Label3D = Label3D.new()
		letters.text = "FAITH"
		letters.font_size = 48
		letters.pixel_size = 0.003
		letters.modulate = Color("e1ddd1")
		letters.position = Vector3(side * 0.30, 0.0, 1.95)
		letters.rotation.y = side * PI / 2.0
		letters.outline_size = 0
		add_child(letters)
	# Glazed sliding canopy / windscreen above the exposed cockpit recess.
	MeshKit.sphere(self, Vector3(0.84, 0.19, 1.6), Vector3(0, 0.48, 0.75), rubber)
	var glass: StandardMaterial3D = MeshKit.material(Color("7a949d"), 0.2)
	MeshKit.sphere(self, Vector3(0.76, 0.63, 1.5), Vector3(0, 0.64, 0.75), glass)
	for z in [0.1, 0.65, 1.3]:
		MeshKit.rod(self, Vector3(-0.34, 0.56, z), Vector3(-0.24, 0.91, z), 0.025, green)
		MeshKit.rod(self, Vector3(-0.24, 0.91, z), Vector3(0.24, 0.91, z), 0.025, green)
		MeshKit.rod(self, Vector3(0.24, 0.91, z), Vector3(0.34, 0.56, z), 0.025, green)
	MeshKit.rod(self, Vector3(0, 0.9, 0.05), Vector3(0, 0.9, 1.4), 0.025, green)
	_wing(2.0, 1.3, 3.3, 0.04, green)
	MeshKit.sphere(self, Vector3(0.15, 1.65, 1.3), Vector3(0, 0.77, 3.58), green)
	for side in [-1.0, 1.0]:
		for i in range(3):
			var flash: Material = MeshKit.material([Color("953c36"), Color("dedfd7"), Color("263949")][i])
			MeshKit.box(self, Vector3(0.014, 0.68, 0.13), Vector3(side * 0.079, 0.85, 3.12 + i * 0.14), flash)
	MeshKit.rod(self, Vector3(0, 0.8, 1.25), Vector3(0, 1.9, 1.15), 0.016, metal)
	MeshKit.rod(self, Vector3(0, 1.9, 1.15), Vector3(0, 1.55, 3.7), 0.008, rubber)
	# Folded naval arrestor hook is cosmetic; no carrier operations yet.
	MeshKit.rod(self, Vector3(0, -0.28, 3.0), Vector3(0, -0.38, 3.85), 0.025, metal)
	_radial_engine()
	_fixed_gear()
	for side in [-1.0, 1.0]:
		_port(Vector3(side * 0.58, 0.10, -2.30), "FuselageGun")
		_port(Vector3(side * 2.5, -0.15, -0.86), "LowerWingGun")

func _fuselage() -> void:
	var rings: Array[Vector3] = [Vector3(-2.8, 0.62, 0.63), Vector3(-1.8, 0.62, 0.6), Vector3(-0.1, 0.48, 0.55), Vector3(1.6, 0.33, 0.39), Vector3(3.2, 0.17, 0.23), Vector3(4.1, 0.07, 0.10)]
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(rings.size() - 1):
		for i in range(24):
			var a: float = TAU * i / 24.0
			var b: float = TAU * (i + 1) / 24.0
			var r: Vector3 = rings[j]
			var s: Vector3 = rings[j + 1]
			var points: Array[Vector3] = [Vector3(cos(a) * r.y, sin(a) * r.z, r.x), Vector3(cos(b) * r.y, sin(b) * r.z, r.x), Vector3(cos(a) * s.y, sin(a) * s.z, s.x), Vector3(cos(b) * s.y, sin(b) * s.z, s.x)]
			var color: Color = Color("adb2af") if sin(a) < -0.25 else Color("4c574a") if j % 2 == 0 else Color("444d58")
			for index in [0, 2, 1, 1, 2, 3]:
				surface.set_color(color)
				surface.add_vertex(points[index])
	surface.generate_normals()
	var mat: StandardMaterial3D = MeshKit.material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	MeshKit.mesh(self, surface.commit(), mat)

func _biplane_wing(span: float, chord: float, z: float, y: float) -> MeshInstance3D:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Almost rectangular fabric-covered wings with rounded tips, not elliptical.
	for side in [-1.0, 1.0]:
		for i in range(32):
			var t0: float = float(i) / 32.0
			var t1: float = float(i + 1) / 32.0
			var c0: float = chord * sqrt(maxf(1.0 - pow(maxf((t0 - 0.83) / 0.17, 0), 2), 0))
			var c1: float = chord * sqrt(maxf(1.0 - pow(maxf((t1 - 0.83) / 0.17, 0), 2), 0))
			var color: Color = Color("4c574a") if sin(t0 * 16 + side) > -0.2 else Color("444d58")
			var points: Array[Vector3] = [Vector3(side * span * t0, y + t0 * 0.09, z - c0 * 0.5), Vector3(side * span * t0, y + t0 * 0.09, z + c0 * 0.5), Vector3(side * span * t1, y + t1 * 0.09, z - c1 * 0.5), Vector3(side * span * t1, y + t1 * 0.09, z + c1 * 0.5)]
			for index in [0, 1, 2, 1, 3, 2]:
				surface.set_color(color)
				surface.add_vertex(points[index])
	surface.generate_normals()
	var mat: StandardMaterial3D = MeshKit.material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return MeshKit.mesh(self, surface.commit(), mat)

func _radial_engine() -> void:
	# Annular cowling leaves the dark radial engine visibly open at the front.
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(32):
		var a: float = TAU * i / 32.0
		var b: float = TAU * (i + 1) / 32.0
		for radii_z in [Vector4(0.73, -2.45, 0.73, -3.24), Vector4(0.73, -3.24, 0.54, -3.24), Vector4(0.54, -3.24, 0.54, -2.45)]:
			var points: Array[Vector3] = [Vector3(cos(a) * radii_z.x, sin(a) * radii_z.x, radii_z.y), Vector3(cos(b) * radii_z.x, sin(b) * radii_z.x, radii_z.y), Vector3(cos(a) * radii_z.z, sin(a) * radii_z.z, radii_z.w), Vector3(cos(b) * radii_z.z, sin(b) * radii_z.z, radii_z.w)]
			for index in [0, 1, 2, 1, 3, 2]:
				surface.add_vertex(points[index])
	surface.generate_normals()
	var cowling: StandardMaterial3D = underside.duplicate() as StandardMaterial3D
	cowling.cull_mode = BaseMaterial3D.CULL_DISABLED
	MeshKit.mesh(self, surface.commit(), cowling)
	var engine: MeshInstance3D = MeshKit.cylinder(self, 0.54, 0.04, Vector3(0, 0, -3.20), rubber)
	engine.rotation.x = PI / 2.0
	var fins: StandardMaterial3D = MeshKit.material(Color("565c5b"), 0.6)
	for i in range(9):
		var direction: Vector3 = Vector3(cos(TAU * i / 9), sin(TAU * i / 9), 0)
		var center: Vector3 = Vector3(0, 0, -3.25)
		MeshKit.rod(self, center + direction * 0.16, center + direction * 0.48, 0.07, metal)
		for ring in range(4):
			var offset: float = 0.28 + ring * 0.05
			MeshKit.rod(self, center + direction * offset, center + direction * (offset + 0.017), 0.091, fins)
	propeller = Node3D.new()
	propeller.position = Vector3(0, 0, -3.43)
	add_child(propeller)
	MeshKit.sphere(propeller, Vector3(0.35, 0.35, 0.36), Vector3(0, 0, -0.07), metal)
	for i in range(3):
		var blade: Node3D = Node3D.new()
		blade.rotation.z = TAU * i / 3.0
		propeller.add_child(blade)
		MeshKit.sphere(blade, Vector3(0.18, 1.23, 0.055), Vector3(0, 0.78, 0), rubber)

func _fixed_gear() -> void:
	for i in range(3):
		var root: Node3D = Node3D.new()
		add_child(root)
		wheel_roots.append(root)
		var radius: float = 0.32 if i < 2 else 0.18
		var tyre: MeshInstance3D = MeshKit.cylinder(root, radius, 0.20, Vector3.ZERO, rubber)
		tyre.rotation.z = PI / 2.0
		var hub: MeshInstance3D = MeshKit.cylinder(root, radius * 0.46, 0.21, Vector3.ZERO, metal)
		hub.rotation.z = PI / 2.0
		struts.append(MeshKit.cylinder(self, 0.065, 0.5, Vector3.ZERO, underside))
		if i < 2:
			gear_links.append(MeshKit.cylinder(self, 0.055, 0.5, Vector3.ZERO, underside))

func _port(pos: Vector3, prefix: String) -> void:
	var port: Marker3D = Marker3D.new()
	port.name = prefix + ("Left" if pos.x < 0 else "Right")
	port.position = pos
	add_child(port)
	gun_ports.append(port)
	var barrel: MeshInstance3D = MeshKit.cylinder(port, 0.045, 0.19, Vector3.ZERO, rubber)
	barrel.rotation.x = PI / 2.0

func _raf_roundel(pos: Vector3, radius: float, side: bool, yellow_ring: bool) -> void:
	var colors: Array[Color] = [Color("223b50"), Color("983b32")]
	var sizes: Array[float] = [1.0, 0.30]
	if yellow_ring:
		colors.assign([Color("d3ab4b"), Color("223b50"), Color("e2ded0"), Color("983b32")])
		sizes.assign([1.0, 0.82, 0.56, 0.26])
	for i in range(colors.size()):
		var disc: MeshInstance3D = MeshKit.cylinder(self, radius * sizes[i], 0.006, pos, MeshKit.material(colors[i]))
		if side:
			disc.rotation.z = PI / 2.0
			disc.position.x += signf(pos.x) * float(i) * 0.008
		else:
			disc.position.y += i * 0.008

func animate(delta: float, throttle: float, gear: LandingGear, broken: bool) -> void:
	super.animate(delta, throttle, gear, broken)
	# Diagonal fixed-gear legs follow the same actual suspension travel as tyres.
	for i in range(2):
		var wheel: Vector3 = wheel_roots[i].position
		var attach: Vector3 = Vector3(signf(wheel.x) * 0.35, -0.4, -1.45)
		var link: MeshInstance3D = gear_links[i]
		link.position = (wheel + attach) * 0.5
		link.scale.y = wheel.distance_to(attach) / 0.5
		var direction: Vector3 = (wheel - attach).normalized()
		link.quaternion = Quaternion(Vector3.UP.cross(direction).normalized(), Vector3.UP.angle_to(direction))
