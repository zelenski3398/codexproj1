extends SceneTree
## Real MaltaWorld captures for map alignment and silhouette review.
## Set MOSTA_CAPTURE_DIR to an existing output directory.

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var world := MaltaWorld.new()
	root.add_child(world)
	var camera := Camera3D.new()
	camera.far = 28000
	camera.near = 0.5
	world.add_child(camera)
	camera.current = true
	for i in 12: await physics_frame
	var center := world.mosta_village.rotunda.global_position
	GameAudioMixer.instance.audio_button.hide()
	var destination := OS.get_environment("MOSTA_CAPTURE_DIR")
	if destination.is_empty(): destination = "/tmp"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1140
	camera.position = center + Vector3(1, 1480, 90)
	camera.look_at(camera.position + Vector3.DOWN, Vector3.FORWARD)
	await _save(destination.path_join("mosta-overhead.png"))
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 46
	camera.position = center + Vector3(124, 185, 270)
	camera.look_at(center + Vector3(0, 11, -14))
	await _save(destination.path_join("mosta-oblique-southeast.png"))
	camera.fov = 55
	camera.position = center + Vector3(-225, 210, 390)
	camera.look_at(center + Vector3(0, 12, -44))
	await _save(destination.path_join("mosta-oblique-southwest.png"))
	camera.fov = 63
	var front := world.mosta_village.rotunda.global_basis.z
	camera.position = center + front * 77 + Vector3.UP * 4.0
	camera.look_at(center + Vector3.UP * 15)
	await _save(destination.path_join("mosta-forecourt.png"))
	quit()

func _save(path: String) -> void:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	var status := root.get_texture().get_image().save_png(path)
	if status != OK: push_error("Could not save %s" % path)
