extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	var scene:=Node3D.new();root.add_child(scene)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("92b1bd");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.65;scene.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-25,0);scene.add_child(light)
	var ground:=StaticBody3D.new();scene.add_child(ground)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(200,1,200);shape.shape=box;shape.position.y=-.5;ground.add_child(shape)
	MeshKit.box(ground,box.size,shape.position,MeshKit.material(Color("8e876d")))
	var aircraft:=EnemyAircraft.new();scene.add_child(aircraft)
	for i in 3:await physics_frame
	aircraft.reset_pending=false;aircraft.freeze=true;aircraft.global_position=Vector3(0,1.4,0);aircraft.linear_velocity=Vector3(0,-65,0)
	aircraft.take_damage(1000);aircraft._finish_impact(aircraft.global_position)
	var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(13,6,17);camera.look_at(Vector3(0,1.5,0));camera.make_current()
	for i in 350:await physics_frame
	aircraft.queue_free()
	# Wait beyond the original twelve-second debris lifetime, demonstrating
	# the lingering world-owned effect and retained charred geometry alone.
	for i in 1400:await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/wreck-fire-preview.png")
	print("WRECK FIRE CAPTURE: saved /tmp/wreck-fire-preview.png")
	AircraftImpactService.obtain().clear_all();scene.queue_free()
	for i in 5:await physics_frame
	quit()
