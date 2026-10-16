extends SceneTree
## Review cameras only; no relocation/camera changes in ordinary gameplay.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	GameAudioMixer.instance.playback_enabled = false
	var world:=MaltaWorld.new()
	root.add_child(world)
	for i in range(5):await physics_frame
	var camera:=Camera3D.new()
	camera.near=1
	camera.far=40000
	camera.fov=45
	world.add_child(camera)
	camera.make_current()
	for label in world.find_children("*","Label3D",true,false):label.visible=false
	GameAudioMixer.instance.audio_button.visible=false
	var origin: Vector3=world.mdina_city.position+Vector3.UP*world.mdina_city.layout.reference_terrain_height
	var views: Array=[
		["mdina-aerial",Vector3(390,390,620),Vector3(0,5,-30)],
		["mdina-bastions",Vector3(240,100,330),Vector3(15,6,70)],
		["mdina-cathedral",Vector3(110,80,125),Vector3(40,24,5)],
		["mdina-gate",Vector3(-27,7,175),Vector3(-27,5,128)]
	]
	for view in views:
		camera.global_position=origin+view[1]
		camera.look_at(origin+view[2])
		for i in range(4):await process_frame
		await RenderingServer.frame_post_draw
		var file: String="res://docs/previews/"+view[0]+".png"
		print("CAPTURE ",file," ",root.get_texture().get_image().save_png(file))
	world.queue_free()
	for i in range(3):await process_frame
	quit()
