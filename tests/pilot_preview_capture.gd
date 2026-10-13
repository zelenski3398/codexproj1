extends SceneTree
## Native Compatibility renders of the real reusable asset and cockpit instances.
var world: Node3D
var camera: Camera3D
var avatar: RafPilotAvatar
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	GameAudioMixer.instance.audio_button.hide()
	world = Node3D.new()
	root.add_child(world)
	var environment: WorldEnvironment = WorldEnvironment.new()
	var settings: Environment = Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("aebac2")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.35
	environment.environment = settings
	world.add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	world.add_child(sun)
	MeshKit.box(world, Vector3(30, 0.03, 30), Vector3(0,-0.035,0), MeshKit.material(Color("929c9c")))
	camera = Camera3D.new()
	camera.fov = 35
	world.add_child(camera)
	camera.make_current()
	avatar = RafPilotAvatar.new()
	world.add_child(avatar)
	await _frames(30)
	camera.position = Vector3(0,1.05,-3.7)
	camera.look_at(Vector3(0,.95,0))
	await _capture("pilot-front")
	camera.position = Vector3(3.7,1.05,0)
	camera.look_at(Vector3(0,.95,0))
	await _capture("pilot-side")
	avatar.set_pose("Walk")
	avatar.animator.advance(0.2)
	avatar.animator.pause()
	camera.position = Vector3(2.4,1.1,-3.3)
	camera.look_at(Vector3(0,.95,0))
	await _capture("pilot-walking")
	avatar.animator.speed_scale = 1
	avatar.set_pose("Seated")
	await _frames(30)
	camera.position = Vector3(2.7,1.3,-2.7)
	camera.look_at(Vector3(0,1.1,-.2))
	await _capture("pilot-seated-pose")
	avatar.hide()
	for kind in ["spitfire", "sea_gladiator"]:
		var model: SpitfireModel = SeaGladiatorModel.new() if kind == "sea_gladiator" else SpitfireModel.new()
		world.add_child(model)
		var seated: RafPilotAvatar = RafPilotAvatar.new()
		model.add_child(seated)
		seated.position = Vector3(0,-.78,.8) if kind == "sea_gladiator" else Vector3(0,-.84,.25)
		seated.set_pose("Seated")
		await _frames(30)
		camera.position = Vector3(2.2,1.6,-1.25) if kind == "spitfire" else Vector3(2.2,1.6,-.3)
		camera.look_at(Vector3(0,.4,.3 if kind == "spitfire" else .8))
		await _capture("pilot-seated-"+kind)
		model.queue_free()
		await _frames(3)
	quit()
func _frames(count: int) -> void:
	for frame in range(count):await process_frame
func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/"+name+".png")
	print("PREVIEW: ",name)
