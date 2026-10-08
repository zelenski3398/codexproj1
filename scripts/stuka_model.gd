class_name StukaModel
extends SpitfireModel
## Original Ju 87-inspired placeholder from the reference: inverted gull wings,
## long framed canopy, fixed spatted wheels, yellow cowling and red spinner.
## This is a mesh approximation, not a imported/authentic historical model.

func _ready() -> void:
	green = MeshKit.material(Color("3c514b"))
	brown = MeshKit.material(Color("53624d"))
	underside = MeshKit.material(Color("819ba2"))
	_fuselage()
	_gull_wings()
	var yellow: StandardMaterial3D = MeshKit.material(Color("e6b52a"))
	var red: StandardMaterial3D = MeshKit.material(Color("af3029"))
	MeshKit.sphere(self, Vector3(1.23, 1.3, 1.75), Vector3(0, 0, -3.0), yellow)
	MeshKit.box(self, Vector3(0.9, 0.2, 0.9), Vector3(0, -0.55, -2.9), rubber)
	for side in [-1.0, 1.0]:
		for i in range(5):
			MeshKit.box(self, Vector3(0.14, 0.12, 0.18), Vector3(side * 0.59, -0.06, -3.25 + i * 0.21), rubber)
	# Long two-seat glazed greenhouse with repeated structural frames.
	var glass: StandardMaterial3D = MeshKit.material(Color("6592a1"), 0.18)
	glass.metallic = 0.25
	MeshKit.sphere(self, Vector3(0.98, 0.94, 3.0), Vector3(0, 0.53, 0.55), glass)
	for z in [-0.6, -0.1, 0.45, 1.0, 1.55]:
		MeshKit.rod(self, Vector3(-0.43, 0.55, z), Vector3(-0.27, 0.9, z), 0.033, green)
		MeshKit.rod(self, Vector3(-0.27, 0.9, z), Vector3(0.27, 0.9, z), 0.033, green)
		MeshKit.rod(self, Vector3(0.27, 0.9, z), Vector3(0.43, 0.55, z), 0.033, green)
	MeshKit.rod(self, Vector3(0, 0.97, -0.75), Vector3(0, 0.97, 1.7), 0.03, green)
	MeshKit.rod(self, Vector3(0, 0.92, 0.9), Vector3(0, 2.0, 0.65), 0.02, metal)
	# Angular tail and broad tailplane rather than the Spitfire's rounded fin.
	MeshKit.box(self, Vector3(0.16, 1.4, 1.25), Vector3(0, 0.58, 3.95), green).rotation.x = -0.13
	MeshKit.box(self, Vector3(0.18, 1.4, 0.24), Vector3(0, 0.59, 4.48), yellow)
	MeshKit.box(self, Vector3(4.4, 0.1, 1.18), Vector3(0, 0.05, 3.6), green)
	for side in [-1.0, 1.0]:
		MeshKit.rod(self, Vector3(0, -0.18, 4), Vector3(side * 1.7, 0, 3.5), 0.035, metal)
		# Fixed landing gear with the unmistakable Stuka wheel fairings.
		MeshKit.rod(self, Vector3(side * 1.7, -0.45, -0.2), Vector3(side * 1.7, -1.55, -0.4), 0.18, green)
		MeshKit.sphere(self, Vector3(0.64, 1.05, 1.5), Vector3(side * 1.7, -1.45, -0.45), green)
		var wheel: MeshInstance3D = MeshKit.cylinder(self, 0.36, 0.24, Vector3(side * 1.7, -1.85, -0.42), rubber)
		wheel.rotation.z = PI / 2.0
		_cross(Vector3(side * 4.6, -0.035, 0.15), false)
		_cross(Vector3(side * 0.3, 0.0, 2.1), true)
		var port: Marker3D = Marker3D.new()
		port.name = "WingGunLeft" if side < 0 else "WingGunRight"
		port.position = Vector3(side * 2.65, -0.34, -1.12)
		add_child(port)
		gun_ports.append(port)
		var barrel: MeshInstance3D = MeshKit.cylinder(port, 0.055, 0.2, Vector3.ZERO, rubber)
		barrel.rotation.x = PI / 2.0
		MeshKit.box(self, Vector3(2.8, 0.12, 0.3), Vector3(side * 3.3, -0.42, 0.15), green)
	# Rear tailwheel and three-blade propeller.
	MeshKit.rod(self, Vector3(0, -0.2, 3.75), Vector3(0, -0.7, 4), 0.055, metal)
	var tailwheel: MeshInstance3D = MeshKit.cylinder(self, 0.19, 0.14, Vector3(0, -0.76, 4), rubber)
	tailwheel.rotation.z = PI / 2.0
	propeller = Node3D.new()
	propeller.position = Vector3(0, 0, -3.92)
	add_child(propeller)
	MeshKit.sphere(propeller, Vector3(0.7, 0.7, 0.9), Vector3(0, 0, -0.25), red)
	for i in range(3):
		var blade: Node3D = Node3D.new()
		blade.rotation.z = TAU * i / 3.0
		propeller.add_child(blade)
		MeshKit.box(blade, Vector3(0.18, 1.4, 0.065), Vector3(0, 0.9, 0), rubber)
		MeshKit.box(blade, Vector3(0.19, 0.13, 0.07), Vector3(0, 1.55, 0), yellow)

func _gull_wings() -> void:
	# Stations encode the inner downward kink and rising outer tapered panels.
	var stations: Array[Vector3] = [Vector3(0, -0.07, 2.9), Vector3(1.7, -0.48, 2.8), Vector3(6.5, 0.24, 1.5), Vector3(7.1, 0.29, 0.85)]
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		for i in range(stations.size() - 1):
			var a: Vector3 = stations[i]
			var b: Vector3 = stations[i + 1]
			var z0: float = a.x * 0.09
			var z1: float = b.x * 0.09
			var points: Array[Vector3] = [Vector3(side * a.x, a.y, z0 - a.z / 2), Vector3(side * a.x, a.y, z0 + a.z / 2), Vector3(side * b.x, b.y, z1 - b.z / 2), Vector3(side * b.x, b.y, z1 + b.z / 2)]
			for index in [0, 1, 2, 1, 3, 2]:
				surface.add_vertex(points[index])
	surface.generate_normals()
	var mat: StandardMaterial3D = green.duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	MeshKit.mesh(self, surface.commit(), mat)
	# Broad camouflage panels, with a modest lift to avoid z-fighting.
	for side in [-1.0, 1.0]:
		var patch: MeshInstance3D = MeshKit.box(self, Vector3(2.9, 0.025, 0.7), Vector3(side * 3.6, -0.18, 0.35), brown)
		patch.rotation.z = side * 0.15

func _cross(pos: Vector3, on_side: bool) -> void:
	var marking: Node3D = Node3D.new()
	marking.position = pos
	if on_side:
		marking.rotation.z = -signf(pos.x) * PI / 2.0
		marking.scale = Vector3.ONE * 0.38
	else:
		marking.rotation.z = signf(pos.x) * atan(0.72 / 4.8)
	add_child(marking)
	var white: StandardMaterial3D = MeshKit.material(Color("dddcc9"))
	for width in [0.48, 0.28]:
		var mat: Material = white if width > 0.3 else rubber
		var lift: float = 0.012 if width > 0.3 else 0.025
		MeshKit.box(marking, Vector3(1.7, 0.008, width), Vector3(0, lift, 0), mat)
		MeshKit.box(marking, Vector3(width, 0.008, 1.7), Vector3(0, lift, 0), mat)

func animate(delta: float, throttle: float, _gear: LandingGear, broken: bool) -> void:
	# Ju 87 gear is fixed, so there is no inherited retract/suspension animation.
	if not broken:
		propeller.rotation.z += delta * (3.0 + throttle * 95.0)

