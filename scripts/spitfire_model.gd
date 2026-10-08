class_name SpitfireModel
extends Node3D
## Recognisable, original mesh placeholder: elliptical wings, tapered fuselage,
## bubble canopy, RAF roundels, fin, tailplane, propeller and three wheels.
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
		var patch := MeshKit.sphere(self, Vector3(2.1, 0.019, 0.9), Vector3(side * 2.35, -0.02, -0.28), brown)
		patch.rotation.y = side * 0.2
		_roundel(Vector3(side * 3.8, 0.035, -0.1), 0.54, false)
		_roundel(Vector3(side * 0.49, 0.1, 1.55), 0.38, true)
	var canopy := MeshKit.material(Color("517f93"), 0.12)
	canopy.metallic = 0.32
	MeshKit.sphere(self, Vector3(0.83, 0.86, 1.65), Vector3(0.0, 0.49, 0.18), canopy)
	MeshKit.rod(self, Vector3(-0.39, 0.45, -0.32), Vector3(0.39, 0.45, -0.32), 0.045, green)
	MeshKit.rod(self, Vector3(0.0, 0.88, -0.55), Vector3(0.0, 0.86, 0.5), 0.035, green)
	MeshKit.box(self, Vector3(0.13, 1.1, 1.0), Vector3(0.0, 0.55, 3.82), green).rotation.x = -0.2
	MeshKit.sphere(self, Vector3(0.16, 0.8, 1.0), Vector3(0.0, 1.05, 3.74), green)
	# Fin flash: original RAF red / white / blue rectangles.
	for side in [-1.0, 1.0]:
		for i in range(3):
			MeshKit.box(self, Vector3(0.015, 0.5, 0.17), Vector3(side * 0.09, 0.82, 3.52 + i * 0.17), MeshKit.material([Color("933d32"), Color("e5e4cf"), Color("263951")][i]))
	MeshKit.box(self, Vector3(0.9, 0.28, 0.9), Vector3(1.55, -0.33, 0.05), underside)
	MeshKit.box(self, Vector3(0.7, 0.22, 0.65), Vector3(-1.55, -0.3, 0.0), underside)
	for side in [-1.0, 1.0]:
		for i in range(5):
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

func _fuselage() -> void:
	var rings: Array[Vector3] = [Vector3(-3.75, 0.29, 0.3), Vector3(-3.1, 0.48, 0.5), Vector3(-1.8, 0.52, 0.6), Vector3(0.0, 0.48, 0.57), Vector3(1.6, 0.35, 0.4), Vector3(3.1, 0.17, 0.23), Vector3(4.3, 0.065, 0.09)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(rings.size() - 1):
		for i in range(20):
			var a := TAU * i / 20.0
			var b := TAU * (i + 1) / 20.0
			var r := rings[j]
			var s := rings[j + 1]
			var points := [Vector3(cos(a) * r.y, sin(a) * r.z, r.x), Vector3(cos(b) * r.y, sin(b) * r.z, r.x), Vector3(cos(a) * s.y, sin(a) * s.z, s.x), Vector3(cos(b) * s.y, sin(b) * s.z, s.x)]
			for index in [0, 2, 1, 1, 2, 3]:
				surface.add_vertex(points[index])
	surface.generate_normals()
	var mat := green.duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	MeshKit.mesh(self, surface.commit(), mat)
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
			for index in [0, 1, 2, 1, 3, 2]:
				surface.add_vertex(vertices[index])
	surface.generate_normals()
	var wing_mat := mat.duplicate() as StandardMaterial3D
	wing_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	MeshKit.mesh(self, surface.commit(), wing_mat)

func _roundel(pos: Vector3, radius: float, side: bool) -> void:
	var colors := [Color("22384f"), Color("e8e3c9"), Color("9e3c31")]
	for i in range(3):
		var disc := MeshKit.cylinder(self, radius * [1.0, 0.67, 0.32][i], 0.006, pos, MeshKit.material(colors[i]))
		if side:
			disc.rotation.z = PI / 2.0
			disc.position.x += signf(pos.x) * float(i) * 0.007
		else:
			disc.position.y += i * 0.007

func animate(delta: float, throttle: float, gear: LandingGear, broken: bool) -> void:
	if not broken:
		propeller.rotation.z += delta * (3.0 + throttle * 95.0)
	for i in range(3):
		wheel_roots[i].visible = gear.extended
		struts[i].visible = gear.extended
		var length := gear.travel[i] - gear.compression[i]
		wheel_roots[i].position = gear.anchors[i] + Vector3.DOWN * length
		struts[i].position = gear.anchors[i] + Vector3.DOWN * length * 0.5
		struts[i].scale.y = length / 0.5

