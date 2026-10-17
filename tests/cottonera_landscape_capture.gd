extends SceneTree
## Actual continuous-world review views; no production transforms are changed.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	GameAudioMixer.instance.playback_enabled = false
	var world := MaltaWorld.new()
	root.add_child(world)
	for i in range(5): await physics_frame
	var camera := Camera3D.new()
	camera.near = .15
	camera.far = 40000
	camera.fov = 52
	world.add_child(camera)
	camera.make_current()
	for label in world.find_children("*", "Label3D", true, false): label.visible = false
	GameAudioMixer.instance.audio_button.visible = false
	var points: Array = world.cottonera_region.manifest.landscape.fields.sections
	# The middle of an actual generated section, not an unrelated preview prop.
	var chosen: Dictionary = points[points.size() / 2]
	var a := MaltaGeography.vector(chosen.a)
	var b := MaltaGeography.vector(chosen.b)
	var middle := (a + b) * .5
	var side := Vector3(b.z-a.z, 0, a.x-b.x).normalized()
	var ground_camera := middle + side * 5 - (b-a).normalized() * 3
	var ground: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(ground_camera.x, 500, ground_camera.z), Vector3(ground_camera.x, -50, ground_camera.z), 1))
	ground_camera.y = (ground.position.y if not ground.is_empty() else middle.y) + 1.7
	var views: Array = [
		["cottonera-walled-fields-aerial", Vector3(11600, 1250, 6700), Vector3(11100, 40, 4900)],
		["cottonera-rubble-wall-ground", ground_camera, middle + Vector3.UP*.5]
	]
	for view in views:
		camera.global_position = view[1]
		camera.look_at(view[2])
		for i in range(6): await process_frame
		await RenderingServer.frame_post_draw
		print("CAPTURE ", view[0], " ", root.get_texture().get_image().save_png("res://docs/previews/" + view[0] + ".png"))
	world.cottonera_region.show_boundary_debug = true
	camera.global_position = views[0][1]
	camera.look_at(views[0][2])
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/cottonera-boundary-debug.png")
	world.queue_free()
	for i in range(4): await process_frame
	quit()
