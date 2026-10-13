extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	GameAudioMixer.instance.audio_button.hide()
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("aebac2")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_energy = 0.6
	settings.ambient_light_color = Color.WHITE
	environment.environment = settings
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40,-30,0)
	world.add_child(sun)
	var asset: PackedScene = load("res://assets/ground/british_aa/British_AA_Emplacement.glb")
	world.add_child(asset.instantiate())
	MeshKit.box(world,Vector3(20,0.05,20),Vector3(0,-0.05,0),MeshKit.material(Color("afa283")))
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(6,4,7)
	camera.look_at(Vector3.UP)
	camera.make_current()
	for i in range(20): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/british-aa.png")
	quit()
