class_name MaltaAirfield
extends Node3D
## Graded takeoff strip/apron above the unmodified measured terrain. All fields
## coexist, with static BVH/box collision and persistent damageable installations.
var record: Dictionary
var parking: Array[Transform3D] = []
var pilot_spawn: Vector3
var installations: Array[AirfieldInstallation] = []
var runway_length: float

func _ready() -> void:
	name = String(record.id).to_pascal_case()
	runway_length = float(record.length)
	var origin: Vector3 = MaltaGeography.vector(record.position)
	var heading: float = deg_to_rad(float(record.heading))
	var grade: float = atan(float(record.slope))
	transform = Transform3D(Basis(Vector3.UP, -heading) * Basis(Vector3.RIGHT, grade), origin)
	var runway: Material = MeshKit.material(Color("777667"))
	var paint: Material = MeshKit.material(Color("eee0b2"))
	_box(Vector3(54, 2, runway_length), Vector3(0, -1, 0), runway)
	# Apron and taxi lane join the strip physically. Spawn/exit points stay on it.
	_box(Vector3(96, 2, 230), Vector3(61, -1, runway_length * 0.31), runway)
	for z in range(-int(runway_length * 0.46), int(runway_length * 0.46), 75):
		MeshKit.box(self, Vector3(1.2, 0.025, 24), Vector3(0, 0.025, z), paint)
	for side in [-1, 1]:
		MeshKit.box(self, Vector3(0.5, 0.025, runway_length - 30), Vector3(side * 25, 0.025, 0), paint)
	# Dispersal slots face the departure direction; 35 m prevents wing overlaps.
	for i in range(record.stationed_aircraft.size()):
		var local_pose: Transform3D = Transform3D(Basis(Vector3.RIGHT, 0.117), Vector3(59, 1.18, runway_length * 0.31 - i * 35))
		parking.append(global_transform * local_pose)
	pilot_spawn = to_global(Vector3(64, 1.1, runway_length * 0.31 + 2))
	for i in range(2):
		var building: AirfieldInstallation = AirfieldInstallation.new()
		building.position = Vector3(93, 5, runway_length * 0.31 - 45 - i * 80)
		building.size = Vector3(22, 10, 32)
		building.display_name = String(record.name) + " hangar"
		add_child(building)
		installations.append(building)
	var label: Label3D = Label3D.new()
	label.text = String(record.name) + "\nDISPERSAL · E TO BOARD"
	label.position = Vector3(72, 12, runway_length * 0.31 + 24)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.font_size = 42
	label.pixel_size = 0.06
	label.visibility_range_end = 700
	add_child(label)

func _box(size: Vector3, pos: Vector3, material: Material) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	add_child(body)
	MeshKit.box(body, size, Vector3.ZERO, material)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func contains(point: Vector3) -> bool:
	var local: Vector3 = to_local(point)
	return absf(local.x) < 125 and absf(local.z) < runway_length * 0.5 + 30 and absf(local.y) < 10
