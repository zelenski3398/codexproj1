extends SceneTree
## Review fixture only; no camera/player relocation is added to gameplay.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	GameAudioMixer.instance.playback_enabled = false
	var world := MaltaWorld.new()
	root.add_child(world)
	for i in range(5): await physics_frame
	var camera := Camera3D.new()
	camera.near = 2
	camera.far = 40000
	camera.fov = 48
	world.add_child(camera)
	camera.make_current()
	var origin := world.valletta_city.global_position
	# Hide labels/widgets only in the review fixture to show the actual mesh.
	for label in world.find_children("*","Label3D",true,false): label.visible = false
	GameAudioMixer.instance.audio_button.visible = false
	var directory := "res://docs/previews"
	DirAccess.make_dir_recursive_absolute(directory)
	var views := [
		["valletta-aerial",Vector3(850,1050,1100),Vector3(80,15,70)],
		["valletta-fort",Vector3(1150,330,-650),Vector3(590,25,-310)],
		["valletta-streets",Vector3(-170,190,440),Vector3(80,35,100)]
	]
	for view in views:
		camera.global_position = origin + view[1]
		camera.look_at(origin + view[2])
		for i in range(4): await process_frame
		await RenderingServer.frame_post_draw
		var file: String = directory.path_join(view[0]+".png")
		print("CAPTURE ",file," ",root.get_texture().get_image().save_png(file))
	world.queue_free()
	for i in range(3): await process_frame
	quit()
