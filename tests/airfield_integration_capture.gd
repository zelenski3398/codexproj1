extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var prefix: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "after"
	var world := MaltaWorld.new()
	root.add_child(world)
	for i in range(12): await process_frame
	GameAudioMixer.instance.audio_button.hide()
	var camera := Camera3D.new()
	camera.far = 100000
	camera.near = .5
	world.add_child(camera)
	camera.make_current()
	for field in world.fields.values():
		var centre: Vector3 = field.to_global(Vector3(20,0,field.runway_length*.31))
		camera.global_position = centre + field.global_basis*Vector3(230,135,270)
		camera.look_at(centre)
		for i in range(6): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/previews/"+prefix+"-"+String(field.record.id)+".png")
	quit()
