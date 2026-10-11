class_name ItalianAircraftModel
extends SpitfireModel
## Original procedural silhouettes, not imported historical 3D assets.
@export_enum("cr42", "c200", "sm79") var kind: String = "c200"
var propellers: Array[Node3D] = []
var defensive_mounts: Array[DefensiveGunMount] = []
var gear_parts: Array[Node3D] = []

func _ready() -> void:
	green = MeshKit.material(Color("66674a"))
	brown = MeshKit.material(Color("92836a"))
	underside = MeshKit.material(Color("b0b0a1"))
	if kind == "sm79":
		_bomber()
	else:
		_fighter()

func _radial(at: Vector3, radius: float) -> void:
	var cowling: MeshInstance3D = MeshKit.cylinder(self, radius, 1.1, at, green)
	cowling.rotation.x = PI / 2
	var engine: MeshInstance3D = MeshKit.cylinder(self, radius * 0.84, 0.05, at + Vector3(0, 0, -0.57), rubber)
	engine.rotation.x = PI / 2
	for i in range(9):
		var angle: float = TAU * i / 9
		MeshKit.sphere(self, Vector3(0.2, 0.25, 0.13), at + Vector3(sin(angle) * radius * 0.6, cos(angle) * radius * 0.6, -0.61), metal)
	var rotor: Node3D = Node3D.new()
	rotor.position = at + Vector3(0, 0, -0.75)
	add_child(rotor)
	propellers.append(rotor)
	MeshKit.sphere(rotor, Vector3.ONE * 0.35, Vector3.ZERO, metal)
	for i in range(3 if kind != "cr42" else 2):
		var blade: Node3D = Node3D.new()
		blade.rotation.z = TAU * i / (3 if kind != "cr42" else 2)
		rotor.add_child(blade)
		MeshKit.box(blade, Vector3(0.16, radius * 1.65, 0.055), Vector3(0, radius * 0.85, 0), rubber)
		MeshKit.box(blade, Vector3(0.17, 0.16, 0.06), Vector3(0, radius * 1.58, 0), brown)

func _fighter() -> void:
	var falco: bool = kind == "cr42"
	MeshKit.sphere(self, Vector3(1.0, 1.15, 7.8), Vector3(0, 0, 0.15), green)
	MeshKit.sphere(self, Vector3(0.95, 0.24, 5.7), Vector3(0, -0.42, 0), underside)
	_radial(Vector3(0, 0, -3.2), 0.7 if falco else 0.78)
	var glass: StandardMaterial3D = MeshKit.material(Color("76949a"), 0.15)
	MeshKit.box(self, Vector3(0.7, 0.3, 0.12), Vector3(0, 0.7, -0.45), glass).rotation.x = 0.3
	MeshKit.sphere(self, Vector3(0.65, 0.16, 0.7), Vector3(0, 0.56, 0), rubber)
	MeshKit.sphere(self, Vector3(0.18, 0.3, 0.18), Vector3(0, 0.68, 0.05), brown)
	_wing(3.25 if falco else 5.29, 1.5 if falco else 2.25, -0.45, -0.3, green)
	if falco:
		_wing(4.85, 1.75, -0.8, 1.45, green)
		for side in [-1.0, 1.0]:
			for x in [2.2, 3.8]:
				MeshKit.rod(self, Vector3(side * x, -0.2, -0.85), Vector3(side * x, 1.45, -0.6), 0.04, metal)
			MeshKit.rod(self, Vector3(side * 0.35, 0.4, -1.2), Vector3(side * 1.2, 1.45, -1.2), 0.03, metal)
			MeshKit.rod(self, Vector3(side * 2.2, -0.2, 0.1), Vector3(side * 3.8, 1.45, -1.3), 0.008, rubber)
	_wing(1.65, 1.0, 3.25, 0.15, green)
	MeshKit.sphere(self, Vector3(0.14, 1.7, 1.5), Vector3(0, 0.65, 3.4), green)
	for side in [-1.0, 1.0]:
		_gear(Vector3(side * 1.35, -0.4, -0.7), falco)
		_marking(Vector3(side * 3.4, 1.59 if falco else -0.15, -0.35), 0.55, false)
		_marking(Vector3(side * 0.5, 0, 1.75), 0.38, true)
		var port: Marker3D = Marker3D.new()
		port.position = Vector3(side * 0.34, 0.27, -3.85)
		add_child(port)
		gun_ports.append(port)
		MeshKit.rod(self, port.position + Vector3(0, 0, 0.3), port.position, 0.035, rubber)
	_tail_wheel(Vector3(0, -0.3, 3.3))
	_tail_cross(Vector3(0.085, 0.73, 3.4))

func _bomber() -> void:
	MeshKit.sphere(self, Vector3(1.75, 1.8, 15.6), Vector3(0, 0, 0.3), green)
	MeshKit.sphere(self, Vector3(1.55, 0.35, 13.1), Vector3(0, -0.69, 0), underside)
	# The Sparviero's raised cockpit/crew hump is distinct from a twin-engine bomber.
	MeshKit.box(self, Vector3(1.55, 1.15, 3.1), Vector3(0, 0.92, -2.3), green)
	var glass: StandardMaterial3D = MeshKit.material(Color("7397a1"), 0.2)
	MeshKit.box(self, Vector3(1.6, 0.65, 1.35), Vector3(0, 1.26, -3.3), glass)
	for x in [-0.65, 0, 0.65]:
		MeshKit.rod(self, Vector3(x, 0.94, -4), Vector3(x, 1.6, -4), 0.025, green)
	_wing(10.6, 3.1, -0.65, -0.35, green)
	_wing(3.2, 1.75, 6.5, 0.15, green)
	MeshKit.sphere(self, Vector3(0.2, 2.5, 2.6), Vector3(0, 1, 6.5), green)
	_radial(Vector3(0, 0, -7), 0.81)
	for side in [-1.0, 1.0]:
		MeshKit.sphere(self, Vector3(1.45, 1.5, 3.4), Vector3(side * 4.4, -0.3, -1.5), green)
		_radial(Vector3(side * 4.4, -0.25, -3.05), 0.78)
		_gear(Vector3(side * 4.4, -0.75, -1), false)
		_marking(Vector3(side * 7.6, -0.19, -0.25), 0.8, false)
		_marking(Vector3(side * 0.77, -0.1, 4), 0.62, true)
	_tail_wheel(Vector3(0, -0.55, 6.4))
	_tail_cross(Vector3(0.11, 1.02, 6.6))
	for at in [Vector3(0, 1.55, -0.45), Vector3(0, -1.0, 1.6)]:
		var mount: DefensiveGunMount = DefensiveGunMount.new()
		mount.position = at
		add_child(mount)
		defensive_mounts.append(mount)
	# Forward hump gun, disabled while prioritising the bombing route.
	var port: Marker3D = Marker3D.new()
	port.position = Vector3(0, 1.5, -4.1)
	add_child(port)
	gun_ports.append(port)

func _gear(at: Vector3, spatted: bool) -> void:
	var root: Node3D = Node3D.new()
	root.position = at
	add_child(root)
	gear_parts.append(root)
	MeshKit.rod(root, Vector3.ZERO, Vector3(0, -0.95, 0), 0.075, metal)
	if spatted:
		MeshKit.sphere(root, Vector3(0.52, 0.75, 1.05), Vector3(0, -0.75, 0), green)
	var wheel: MeshInstance3D = MeshKit.cylinder(root, 0.37 if kind != "sm79" else 0.48, 0.24, Vector3(0, -1, 0), rubber)
	wheel.rotation.z = PI / 2

func _tail_wheel(at: Vector3) -> void:
	MeshKit.rod(self, at, at + Vector3.DOWN * 0.38, 0.035, metal)
	var wheel: MeshInstance3D = MeshKit.cylinder(self, 0.17, 0.13, at + Vector3.DOWN * 0.48, rubber)
	wheel.rotation.z = PI / 2

func _marking(at: Vector3, radius: float, side: bool) -> void:
	var white: StandardMaterial3D = MeshKit.material(Color("e4e0cc"))
	var disc: MeshInstance3D = MeshKit.cylinder(self, radius, 0.012, at, white)
	if side:
		disc.rotation.z = PI / 2
	# Simplified period Italian three-fasces emblem, geometry only.
	for stripe in [-1.0, 0.0, 1.0]:
		var offset: Vector3 = Vector3(0, stripe * radius * 0.4, 0) if side else Vector3(stripe * radius * 0.4, 0, 0)
		MeshKit.box(self, Vector3(0.017, radius * 0.13, radius * 1.1) if side else Vector3(radius * 0.13, 0.017, radius * 1.1), at + offset + (Vector3(signf(at.x) * 0.015, 0, 0) if side else Vector3.UP * 0.015), rubber)

func _tail_cross(at: Vector3) -> void:
	var white: StandardMaterial3D = MeshKit.material(Color("dddccb"))
	for side in [-1.0, 1.0]:
		MeshKit.box(self, Vector3(0.025, 1.05, 0.15), Vector3(side * at.x, at.y, at.z), white)
		MeshKit.box(self, Vector3(0.025, 0.17, 0.9), Vector3(side * at.x, at.y, at.z), white)

func animate(delta: float, throttle: float, gear: LandingGear, broken: bool) -> void:
	for rotor in propellers:
		if not broken:
			rotor.rotation.z += delta * (3 + throttle * 95)
	for part in gear_parts:
		part.visible = gear.extended or kind == "cr42"
