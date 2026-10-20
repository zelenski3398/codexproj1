extends SceneTree
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await process_frame
func capture(camera: Camera3D,point: Vector3,target: Vector3,name: String) -> void:
	camera.global_position=point;camera.look_at(target);camera.make_current()
	await frames(6)
	await RenderingServer.frame_post_draw
	print("CAPTURE ",name,": ",root.get_texture().get_image().save_png("res://docs/previews/"+name+".png"))
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	var game=load("res://main.tscn").instantiate();root.add_child(game);game.start_free_roam("sea_gladiator")
	await frames(30)
	var mission: MaltaMission=game.malta_mission
	var aircraft: FlightAircraft=mission.initial_aircraft
	var camera:=Camera3D.new();camera.near=.4;camera.far=4000;camera.fov=58
	game.add_child(camera)
	await capture(camera,aircraft.to_global(Vector3(10,4,-12)),aircraft.to_global(Vector3(0,1,0)),"recovery-hangar-departure")
	mission.board_nearest()
	aircraft.request_reset()
	aircraft.pending_reset_pose=mission.world.fields.ta_qali.global_transform*Transform3D(Basis(Vector3.RIGHT,.117),Vector3(-110,1.18,80))
	await frames(8)
	aircraft.take_damage(1000)
	await frames(4)
	mission.leave_aircraft();mission.pilot.take_damage(17)
	mission.recovery.response_seconds=.1;mission.recovery.request()
	for i in 600:
		await physics_frame
		if mission.recovery.state=="READY":break
	var pickup: Vector3=mission.recovery.truck.global_position
	await capture(camera,pickup+Vector3(13,6,-18),pickup+Vector3.UP,"recovery-truck-pickup")
	game.restart_malta();await frames(10)
	mission=game.malta_mission;mission.board_nearest();aircraft=mission.occupied
	aircraft.request_reset();aircraft.pending_reset_pose=Transform3D(Basis.IDENTITY,Vector3(50000,4,50000));aircraft.pending_reset_velocity=Vector3(0,-3,0)
	for i in 600:
		await physics_frame
		if aircraft.impact_effects.water:break
	mission.leave_aircraft();mission.recovery.response_seconds=.1;mission.recovery.request()
	for i in 600:
		await physics_frame
		if mission.recovery.state=="READY":break
	pickup=mission.recovery.truck.global_position
	await capture(camera,pickup+Vector3(13,7,-15),pickup,"recovery-sea-pontoon")
	AircraftImpactService.obtain().clear_all()
	GameAudioMixer.instance.music.stop();GameAudioMixer.instance.music.stream=null
	game.queue_free();await frames(12);RenderingServer.force_sync();quit()
