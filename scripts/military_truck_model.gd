class_name MilitaryTruckModel
extends Node3D
## Original simplified mesh model, inspired by the provided vintage truck photo.
var steering_pivots: Array[Node3D] = []
var wheel_pivots: Array[Node3D] = []
var driver: RafPilotAvatar
static var paint: StandardMaterial3D
var spin: float = 0
func _ready() -> void:
	if paint == null:
		paint = MeshKit.material(Color.WHITE,0.82)
		paint.albedo_texture = load("res://assets/vehicles/stone_camouflage.png")
	var metal := MeshKit.material(Color("45473c"),0.75)
	var canvas := MeshKit.material(Color("787966"),0.95)
	var rubber := MeshKit.material(Color("242726"),0.94)
	var glass := MeshKit.material(Color(0.5,0.65,0.69,0.3),0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Chassis, high curved bonnet and a separate enclosed cab / canvas cargo body.
	MeshKit.box(self,Vector3(1.6,0.2,4.35),Vector3(0,0.5,0),metal)
	MeshKit.box(self,Vector3(1.85,0.65,2.08),Vector3(0,0.95,1.14),paint)
	MeshKit.box(self,Vector3(1.88,1.1,2.06),Vector3(0,1.76,1.12),canvas)
	MeshKit.sphere(self,Vector3(1.90,0.28,2.08),Vector3(0,2.22,1.12),canvas)
	# Raised canvas seams and hanging fastening straps.
	for side in [-1,1]:
		for z in [0.35,0.95,1.6,2.05]:
			MeshKit.rod(self,Vector3(side*.95,1.14,z),Vector3(side*.95,2.1,z),0.014,canvas)
			MeshKit.box(self,Vector3(.04,.34,.03),Vector3(side*.97,1.28,z),metal)
	MeshKit.box(self,Vector3(1.78,0.8,1.32),Vector3(0,1.03,-.55),paint)
	MeshKit.sphere(self,Vector3(1.76,.4,1.38),Vector3(0,1.23,-1.5),paint)
	MeshKit.box(self,Vector3(1.46,.50,1.16),Vector3(0,1.04,-1.55),paint)
	MeshKit.box(self,Vector3(1.40,.7,.12),Vector3(0,.95,-2.13),metal)
	for x in range(-5,6): MeshKit.box(self,Vector3(.025,.57,.025),Vector3(x*.105,.98,-2.20),paint)
	MeshKit.box(self,Vector3(2.13,.14,.16),Vector3(0,.54,-2.31),paint)
	MeshKit.box(self,Vector3(1.77,.17,1.38),Vector3(0,2.01,-.54),paint)
	for side in [-1,1]:
		for z in [-1.16,.1]: MeshKit.rod(self,Vector3(side*.86,1.36,z),Vector3(side*.86,1.99,z+.04),.042,paint)
		MeshKit.box(self,Vector3(.025,.56,1.13),Vector3(side*.86,1.67,-.51),glass)
		MeshKit.box(self,Vector3(.12,.035,.035),Vector3(side*.94,1.32,-.28),metal)
		MeshKit.box(self,Vector3(.31,.07,.8),Vector3(side*1.03,.57,-.4),metal)
		MeshKit.rod(self,Vector3(side*.9,1.8,-1.0),Vector3(side*1.12,1.88,-1.1),.018,metal)
		MeshKit.box(self,Vector3(.13,.20,.04),Vector3(side*1.12,1.88,-1.1),metal)
		var lamp := MeshKit.sphere(self,Vector3(.18,.18,.1),Vector3(side*.83,.98,-2.13),MeshKit.material(Color("d5d4b1")))
		lamp.rotation.x = .15
	MeshKit.box(self,Vector3(1.65,.55,.025),Vector3(0,1.67,-1.16),glass)
	MeshKit.rod(self,Vector3(0,1.4,-1.18),Vector3(0,1.96,-1.15),.025,paint)
	MeshKit.box(self,Vector3(1.55,.25,.12),Vector3(0,1.3,-1.01),metal)
	for side in [-1,1]:
		MeshKit.box(self,Vector3(.6,.14,.55),Vector3(side*.4,.78,-.45),metal)
		MeshKit.box(self,Vector3(.6,.5,.12),Vector3(side*.4,1.03,-.12),metal)
	for x in [-.97,.97]:
		for z in [-1.39,1.39]:
			var steer := Node3D.new()
			steer.position = Vector3(x,.46,z)
			add_child(steer)
			if z < 0: steering_pivots.append(steer)
			var wheel := Node3D.new()
			steer.add_child(wheel)
			wheel_pivots.append(wheel)
			_wheel(wheel,rubber,paint)
			_fender(x,z,paint)
	# Spare tyre lies over the cab, matching the photo; metal hoops, toolbox.
	var spare := MeshKit.cylinder(self,.44,.24,Vector3(0,2.23,-.55),rubber)
	MeshKit.cylinder(self,.25,.255,spare.position,paint)
	MeshKit.box(self,Vector3(.62,.23,.35),Vector3(-.58,.62,.45),metal)
	driver = RafPilotAvatar.new()
	driver.position = Vector3(.4,.16,-.4)
	add_child(driver)
	driver.set_pose("Seated")
	driver.visible = false
	_cull(self)

func _wheel(root: Node3D, rubber: Material, rim: Material) -> void:
	var tire := MeshKit.cylinder(root,.46,.28,Vector3.ZERO,rubber)
	tire.rotation.z = PI/2
	var hub := MeshKit.cylinder(root,.27,.30,Vector3.ZERO,rim)
	hub.rotation.z = PI/2
	for side in [-1,1]:
		for i in range(6):
			var angle := i * TAU/6
			MeshKit.sphere(root,Vector3.ONE*.035,Vector3(side*.158,sin(angle)*.16,cos(angle)*.16),MeshKit.material(Color("7a7966")))

func _fender(x: float,z: float,mat: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(16):
		var a := i*PI/16
		var b := (i+1)*PI/16
		var points: Array[Vector3] = [Vector3(x-.19,.46+sin(a)*.61,z+cos(a)*.61),Vector3(x+.19,.46+sin(a)*.61,z+cos(a)*.61),Vector3(x-.19,.46+sin(b)*.61,z+cos(b)*.61),Vector3(x+.19,.46+sin(b)*.61,z+cos(b)*.61)]
		for index in [0,2,1,1,2,3]:
			tool.set_uv(Vector2(points[index].z,points[index].y))
			tool.add_vertex(points[index])
	tool.generate_normals()
	var fender := MeshKit.mesh(self,tool.commit(),mat)
	fender.material_override = mat.duplicate()
	fender.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED

func animate(speed: float, steering: float,delta: float) -> void:
	spin -= speed/.46*delta
	for wheel in wheel_pivots: wheel.rotation.x = spin
	for pivot in steering_pivots: pivot.rotation.y = -steering*.48

func _cull(node: Node) -> void:
	if node is MeshInstance3D: node.visibility_range_end = 2000
	for child in node.get_children(): _cull(child)
