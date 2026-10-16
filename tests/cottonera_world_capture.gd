extends SceneTree
## Review cameras only; no production movement or coordinate changes.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	var world:=MaltaWorld.new()
	root.add_child(world)
	for i in range(5): await physics_frame
	var camera:=Camera3D.new()
	camera.near=1
	camera.far=40000
	camera.fov=50
	world.add_child(camera)
	camera.make_current()
	for label in world.find_children("*","Label3D",true,false): label.visible=false
	GameAudioMixer.instance.audio_button.visible=false
	var origin:=Vector3(11000,0,4600)
	var views: Array=[
		["cottonera-aerial",Vector3(-1000,1200,-1500),Vector3(100,10,150)],
		["cottonera-harbour",Vector3(-800,300,-600),Vector3(100,20,100)],
		["cottonera-streets",Vector3(320,180,520),Vector3(100,25,150)]
	]
	for view in views:
		camera.global_position=origin+view[1]
		camera.look_at(origin+view[2])
		for i in range(5): await process_frame
		await RenderingServer.frame_post_draw
		print("CAPTURE ",view[0]," ",root.get_texture().get_image().save_png("res://docs/previews/"+view[0]+".png"))
	world.queue_free()
	for i in range(4): await process_frame
	quit()
