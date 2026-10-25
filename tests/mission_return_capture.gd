extends SceneTree
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await process_frame
func capture(name: String) -> void:
	await frames(5);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/mission-return-"+name+".png")
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	var game=load("res://main.tscn").instantiate();root.add_child(game);game.start_test_departure("spitfire");await frames(60)
	game.malta_mission.board_nearest()
	var plane: FlightAircraft=game.aircraft
	plane.global_transform=Transform3D(Basis.IDENTITY,Vector3(0,150,400));plane.linear_velocity=Vector3(0,0,-60)
	plane.pilot.automated=true;plane.engine_running=true;plane.pilot.throttle=.65
	# Install the authored result controller without spawning a formation.
	var controller:=VallettaInterception.new();controller.session=game;game.add_child(controller);game.interception=controller
	controller._finish(true,"Bomber and escort destroyed — Valletta defended")
	await capture("airborne")
	await preload("res://tests/return_landing_fixture.gd").park(game)
	if not controller.success:
		push_error("Capture fixture did not land: altitude=%s contacts=%s pending=%s"%[plane.altitude,plane.gear.contact_count,game.malta_mission.return_flow.pending]);quit(1);return
	await capture("landed")
	game.queue_free();await frames(5);quit()
