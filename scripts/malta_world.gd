class_name MaltaWorld
extends Node3D
## A single 1:1 environment. Only built on mission start; no travel triggers.
var fields: Dictionary = {}
var trucks: Array[MilitaryTruck] = []
var terrain: Node3D
var terrain_appearance: MaltaTerrainAppearance
var mesh_count: int = 0
var bounds: AABB
var sea: MeshInstance3D
var aa_battery: AirfieldAABattery
var cottonera_region: CottoneraRegion
var mdina_city: MdinaCity
var valletta_city: VallettaCity
var landscape_details: MaltaLandscapeDetails

func _ready() -> void:
	name = "ContinuousMalta"
	terrain = preload("res://assets/malta/terrain.glb").instantiate()
	add_child(terrain)
	terrain_appearance = MaltaTerrainAppearance.new()
	terrain_appearance.name = "TerrainAppearance"
	add_child(terrain_appearance)
	_prepare_terrain(terrain)
	# Original island instances retain imported mesh LODs. Static concave shapes
	# build per-island BVHs once; they never rebuild or unload during flight.
	var raw: Array = MaltaGeography.data().terrain_bounds
	bounds = AABB(MaltaGeography.vector(raw[0]), MaltaGeography.vector(raw[1]) - MaltaGeography.vector(raw[0]))
	var sea_material: Material = preload("res://assets/malta/materials/sea.tres")
	sea = MeshKit.box(self, Vector3(240000, 1, 240000), Vector3(0, -0.5, 0), sea_material)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Infinite collision plane supports rays/impacts beyond the visible horizon;
	# the display follows the active camera in XZ, leaving physics unrestricted.
	var water: StaticBody3D = StaticBody3D.new()
	water.name = "MediterraneanSea"
	add_child(water)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = WorldBoundaryShape3D.new()
	water.add_child(collision)
	for record in MaltaGeography.data().airfields:
		var field: MaltaAirfield = MaltaAirfield.new()
		field.record = record
		add_child(field)
		fields[record.id] = field
		var truck := MilitaryTruck.new()
		truck.name = String(record.id) + "_MilitaryTruck"
		add_child(truck)
		truck.global_transform = Transform3D(Basis(Vector3.UP,-deg_to_rad(float(record.heading))),field.to_global(Vector3(78,0.04,field.runway_length*0.31+12)))
		trucks.append(truck)
	aa_battery = AirfieldAABattery.new()
	aa_battery.world = self
	add_child(aa_battery)
	_lighting()
	for marker in MaltaGeography.data().landmarks:
		var label: Label3D = Label3D.new()
		label.text = marker.name
		label.position = MaltaGeography.vector(marker.position) + Vector3.UP * 40
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 60
		label.pixel_size = 0.25
		label.visibility_range_end = 7000
		add_child(label)
	cottonera_region = CottoneraRegion.new()
	add_child(cottonera_region)
	mdina_city = MdinaCity.new()
	add_child(mdina_city)
	valletta_city = VallettaCity.new()
	add_child(valletta_city)
	landscape_details = MaltaLandscapeDetails.new()
	landscape_details.world = self
	add_child(landscape_details)
	terrain_appearance.debug_mode_changed.connect(func(enabled: bool):
		landscape_details.visible = not enabled
		valletta_city.visible = not enabled
		mdina_city.visible = not enabled
		cottonera_region.visible = not enabled)

func _prepare_terrain(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh: MeshInstance3D = node
		mesh_count += 1
		terrain_appearance.register_mesh(mesh)
		# Keep narrow road masks/patch boundaries intact; other island meshes
		# retain distance LOD. Road patches use frustum culling instead.
		mesh.lod_bias = 128.0 if (String(mesh.name).begins_with("RoadGround") or String(mesh.name) == "Malta") else 0.6
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.create_trimesh_collision()
	for child in node.get_children():
		_prepare_terrain(child)

func _lighting() -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff2d5")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250
	add_child(sun)
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	material.sky_top_color = Color("5081ae")
	material.sky_horizon_color = Color("b8d3dc")
	material.ground_horizon_color = Color("b8d3dc")
	sky.sky_material = material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c5d7e4")
	environment.ambient_light_energy = 0.4
	environment.fog_enabled = true
	environment.fog_density = 0.000012
	environment.fog_light_color = Color("b8d3dc")
	world.environment = environment
	add_child(world)

func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		sea.position.x = camera.global_position.x
		sea.position.z = camera.global_position.z
