class_name MaltaAirfield
extends Node3D
## Terrain-supported graded strip/apron. Only the island mesh collides under
## these visual surfaces; buildings retain their own solid collision.
var record: Dictionary
var parking: Array[Transform3D] = []
var access_record: Dictionary
var apron_surface: MeshInstance3D
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
	# Millimetre-scale visual offset; graded terrain is the sole ground collider.
	var runway: Material = preload("res://assets/malta/materials/airfield.tres")
	var paint: Material = MeshKit.material(Color("eee0b2"))
	_surface(Vector2(54,runway_length),Vector3(0,0.015,0),runway)
	# Apron and taxi lane join the strip physically. Spawn/exit points stay on it.
	access_record=MaltaBaseAccess.field(String(record.id))
	var apron_material: ShaderMaterial=(runway as ShaderMaterial).duplicate()
	MaltaBaseAccess.paint(apron_material,record)
	apron_surface=_surface(Vector2(96,230),Vector3(61,0.015,runway_length*0.31),apron_material)
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
		var ground := to_global(Vector3(93,0,runway_length*.31-45-i*80))
		building.global_basis = Basis(Vector3.UP,-heading)
		building.global_position = ground+Vector3.UP*4.85
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

func _surface(size: Vector2,pos: Vector3,material: Material) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	return MeshKit.mesh(self,mesh,material,pos)

func contains(point: Vector3) -> bool:
	var local: Vector3 = to_local(point)
	return absf(local.x) < 125 and absf(local.z) < runway_length * 0.5 + 30 and absf(local.y) < 10
