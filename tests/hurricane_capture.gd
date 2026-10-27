extends SceneTree
func _initialize() -> void:call_deferred("run")
func frames(n: int=4) -> void:
	for i in n:await process_frame
func capture(name: String) -> void:
	await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/hurricane-"+name+".png")
func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();var settings:=Environment.new();settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("9bafb8");settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color.WHITE;settings.ambient_light_energy=.65;env.environment=settings;world.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-35,0);light.light_energy=1.1;world.add_child(light)
	var model:=HurricaneModel.new();world.add_child(model)
	var gear:=LandingGear.new();world.add_child(gear);gear.anchors=[Vector3(-1.55,-.68,-1.05),Vector3(1.55,-.68,-1.05),Vector3(0,-.25,4.65)];model.animate(0,0,gear,false)
	var camera:=Camera3D.new();camera.fov=42;world.add_child(camera);camera.make_current()
	camera.position=Vector3(-11,4.5,-13);camera.look_at(Vector3(0,.2,.2));await capture("front-quarter")
	camera.position=Vector3(16,3,1);camera.look_at(Vector3(0,.2,.2));await capture("side")
	camera.position=Vector3(0,19,.2);camera.look_at(Vector3(0,0,.2),Vector3.FORWARD);await capture("planform")
	world.queue_free();await frames()
	GameAudioMixer.instance.playback_enabled=false
	var game=load("res://main.tscn").instantiate();root.add_child(game);game.start_malta("luqa","hurricane","encounter");await frames(50)
	var plane: FlightAircraft=game.malta_mission.initial_aircraft
	var view:=Camera3D.new();game.add_child(view);view.fov=65;view.far=100000
	view.global_position=plane.to_global(Vector3(10,2.8,-11));view.look_at(plane.global_position+Vector3.UP*.4);view.make_current();await capture("hangar")
	game.queue_free();await frames();quit()
