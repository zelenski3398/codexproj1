class_name Airfield
extends Node3D
## A bounded 10 km patch of countryside, generated deterministically.
const EXTENT: float = 5000.0
var grass := MeshKit.material(Color("6e7c50"))
var concrete := MeshKit.material(Color("4b504c"))
var paint := MeshKit.material(Color("dedcc8"))
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 1940
	_terrain()
	_runway()
	_buildings()
	_countryside()
	_lighting()

static func height_at(x: float, z: float) -> float:
	var field_distance := maxf(absf(x) - 290.0, absf(z) - 1120.0)
	var fade := smoothstep(0.0, 900.0, field_distance)
	return fade * (22.0 + sin(x * 0.0034 + z * 0.001) * 15.0 + sin(z * 0.0041) * 13.0 + cos(x * 0.006 - z * 0.003) * 9.0)

func _terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cells := 100
	var step := EXTENT * 2.0 / cells
	for x in range(cells):
		for z in range(cells):
			var x0 := -EXTENT + x * step
			var z0 := -EXTENT + z * step
			var positions := [Vector3(x0, height_at(x0, z0), z0), Vector3(x0 + step, height_at(x0 + step, z0), z0), Vector3(x0, height_at(x0, z0 + step), z0 + step), Vector3(x0 + step, height_at(x0 + step, z0 + step), z0 + step)]
			var tint := Color("718252").lerp(Color("62754b"), rng.randf())
			for index in [0, 1, 2, 1, 3, 2]:
				surface.set_color(tint)
				surface.add_vertex(positions[index])
	surface.generate_normals()
	var mat := MeshKit.material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	var ground := MeshKit.mesh(self, surface.commit(), mat)
	ground.create_trimesh_collision()

func _static_box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	var visual := MeshKit.box(body, size, Vector3.ZERO, mat)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	return visual

func _runway() -> void:
	_static_box(Vector3(45.0, 0.15, 1800.0), Vector3(0.0, -0.045, 0.0), concrete)
	MeshKit.box(self, Vector3(85.0, 0.03, 220.0), Vector3(67.0, 0.035, 560.0), concrete)
	MeshKit.box(self, Vector3(48.0, 0.03, 18.0), Vector3(44.0, 0.04, 620.0), concrete)
	for z in range(-830, 850, 70):
		MeshKit.box(self, Vector3(1.1, 0.015, 24.0), Vector3(0.0, 0.038, z), paint)
	for side in [-1.0, 1.0]:
		MeshKit.box(self, Vector3(0.35, 0.015, 1740.0), Vector3(side * 21.0, 0.038, 0.0), paint)
		for end in [-1.0, 1.0]:
			for i in range(5):
				MeshKit.box(self, Vector3(1.5, 0.015, 22.0), Vector3(side * (4.0 + i * 3.0), 0.04, end * 860.0), paint)
	for z in range(-880, 900, 85):
		for side in [-1.0, 1.0]:
			MeshKit.box(self, Vector3(0.5, 0.4, 0.5), Vector3(side * 23.5, 0.2, z), paint)
	# Physical threshold numerals can be read from the chase camera.
	for end in [-1.0, 1.0]:
		var text := Label3D.new()
		text.text = "36" if end > 0.0 else "18"
		text.font_size = 120
		text.pixel_size = 0.05
		text.modulate = Color("dedcc8")
		text.position = Vector3(0.0, 0.065, end * 820.0)
		text.rotation_degrees = Vector3(-90.0, 0.0, 0.0 if end > 0.0 else 180.0)
		add_child(text)

func _buildings() -> void:
	var brick := MeshKit.material(Color("89725c"))
	var roof := MeshKit.material(Color("4d5959"))
	var window := MeshKit.material(Color("9ab0b2"), 0.25)
	for i in range(3):
		var pos := Vector3(133.0, 0.0, 455.0 + i * 90.0)
		_static_box(Vector3(42.0, 13.0, 48.0), pos + Vector3.UP * 6.5, roof)
		MeshKit.box(self, Vector3(0.1, 10.0, 39.0), pos + Vector3(-21.1, 5.0, 0.0), MeshKit.material(Color("303a37")))
		for line in range(5):
			MeshKit.box(self, Vector3(0.15, 10.0, 0.2), pos + Vector3(-21.2, 5.0, -18.0 + line * 9.0), metal_color())
	_static_box(Vector3(16.0, 13.0, 18.0), Vector3(100.0, 6.5, 300.0), brick)
	_static_box(Vector3(19.0, 4.0, 21.0), Vector3(100.0, 15.0, 300.0), roof)
	MeshKit.box(self, Vector3(19.1, 2.0, 21.1), Vector3(100.0, 15.5, 300.0), window)
	_static_box(Vector3(25.0, 5.0, 13.0), Vector3(170.0, 2.5, 295.0), brick)
	_static_box(Vector3(28.0, 0.3, 16.0), Vector3(170.0, 5.2, 295.0), roof)
	# Windsock points toward the runway; there is no simulated wind yet.
	MeshKit.cylinder(self, 0.1, 9.0, Vector3(-65.0, 4.5, 650.0), paint)
	for i in range(6):
		var sock := MeshKit.cylinder(self, 0.55 - i * 0.06, 0.5, Vector3(-65.0, 9.0 - i * 0.08, 650.0 - i * 0.45), MeshKit.material(Color("be6f42") if i % 2 == 0 else Color("e8dfc6")))
		sock.rotation.x = PI / 2.0

func metal_color() -> Material:
	return MeshKit.material(Color("5e6865"))

func _countryside() -> void:
	var trunk := MeshKit.material(Color("65533d"))
	var foliage := [MeshKit.material(Color("435b38")), MeshKit.material(Color("52673c")), MeshKit.material(Color("677447"))]
	for i in range(210):
		var x := rng.randf_range(-3900.0, 3900.0)
		var z := rng.randf_range(-3900.0, 3900.0)
		if absf(x) < 300.0 and absf(z) < 1150.0:
			continue
		var base := Vector3(x, height_at(x, z), z)
		var height := rng.randf_range(8.0, 16.0)
		MeshKit.cylinder(self, 0.6, height * 0.6, base + Vector3.UP * height * 0.3, trunk)
		MeshKit.sphere(self, Vector3(height * 0.75, height, height * 0.75), base + Vector3.UP * height * 0.8, foliage[i % 3])
	# Crops and hedges provide scale and landmarks from altitude.
	for i in range(45):
		var x := rng.randf_range(-4000.0, 4000.0)
		var z := rng.randf_range(-4000.0, 4000.0)
		if absf(x) < 450.0 and absf(z) < 1300.0:
			continue
		var size := rng.randf_range(160.0, 400.0)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for a in range(8):
			for b in range(8):
				var x0 := x + size * a / 8.0
				var z0 := z + size * b / 8.0
				var d := size / 8.0
				for v in [Vector2(x0, z0), Vector2(x0 + d, z0), Vector2(x0, z0 + d), Vector2(x0 + d, z0), Vector2(x0 + d, z0 + d), Vector2(x0, z0 + d)]:
					surface.add_vertex(Vector3(v.x, height_at(v.x, v.y) + 0.25, v.y))
		var mat := MeshKit.material([Color("969268"), Color("7c8454"), Color("8b8059")][i % 3])
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		surface.generate_normals()
		MeshKit.mesh(self, surface.commit(), mat)
		for k in range(8):
			var px := x + k * size / 8.0
			MeshKit.box(self, Vector3(size / 8.0, 3.0, 3.0), Vector3(px, height_at(px, z) + 1.5, z), foliage[0])

func _lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	sun.light_color = Color("fff1d3")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 230.0
	add_child(sun)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("658fa9")
	sky_mat.sky_horizon_color = Color("c1d1ce")
	sky_mat.ground_horizon_color = Color("c1d1ce")
	sky_mat.ground_bottom_color = Color("687653")
	sky.sky_material = sky_mat
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("bccfd9")
	environment.ambient_light_energy = 0.3
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_light_color = Color("bdccc4")
	environment.fog_density = 0.000035
	environment.fog_sky_affect = 0.2
	world.environment = environment
	add_child(world)
