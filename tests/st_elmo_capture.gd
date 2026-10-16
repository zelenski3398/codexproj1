extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	var world:=MaltaWorld.new()
	root.add_child(world)
	for i in range(8):await physics_frame
	var camera:=Camera3D.new()
	camera.far=40000;camera.fov=48
	world.add_child(camera);camera.make_current()
	GameAudioMixer.instance.audio_button.hide()
	for label in world.find_children("*","Label3D",true,false):label.hide()
	var point:=StElmoLocations.position_for("st_elmo")
	var forward:=Vector3(world.valletta_city.layout.grid_forward_xz[0],0,world.valletta_city.layout.grid_forward_xz[1])
	for view in [["st-elmo-overview",point+Vector3(-210,220,240),point],["st-elmo-courtyard",point-forward*25+Vector3.UP*2,point+forward*12+Vector3.UP*2],["st-elmo-bofors",world.fort_battery.guns[0].global_position+Vector3(7,5,9),world.fort_battery.guns[0].global_position+Vector3(0,1.5,0)]]:
		camera.global_position=view[1];camera.look_at(view[2])
		for i in range(6):await process_frame
		await RenderingServer.frame_post_draw
		print("CAPTURE ",view[0]," ",root.get_texture().get_image().save_png("res://docs/previews/"+view[0]+".png"))
	world.queue_free()
	for i in range(4):await process_frame
	quit()
