extends SceneTree
## Native camera survey. Set WARTIME_CAPTURE_DIR to an existing directory.

func _initialize() -> void:
	call_deferred("_survey")


func _survey() -> void:
	var world := MaltaWorld.new()
	root.add_child(world)
	var camera := Camera3D.new()
	camera.far = 26000
	camera.near = .6
	world.add_child(camera)
	camera.current = true
	for i in 42:
		await physics_frame
	GameAudioMixer.instance.audio_button.hide()
	var destination := OS.get_environment("WARTIME_CAPTURE_DIR")
	for record in WartimeVillages.layout().sites:
		var district: WartimeDistrict = world.wartime_villages.districts[record.id]
		var bounds: Array = record.bounds
		var h := _aim_height(district)
		var middle := Vector3((bounds[0] + bounds[2]) / 2.0, h, (bounds[1] + bounds[3]) / 2.0)
		var span := maxf(float(bounds[3] - bounds[1]), float(bounds[2] - bounds[0]) * .63)
		await _overhead(camera, middle, span, destination.path_join(record.id + "-overhead.jpg"))
		var church: WartimeChurch = district.churches.get(record.id)
		var center := middle if church == null else church.global_position
		var direction := Vector3(.45, 0, 1).normalized() if church == null else (church.global_basis.z + church.global_basis.x * .43).normalized()
		await _oblique(camera, center, direction, maxf(135, minf(480, span * .53)), destination.path_join(record.id + "-oblique.jpg"))
		if record.id == "qormi":
			await _measure(camera, center)
	var sites := {"mosta": world.mosta_village.rotunda.global_position, "mdina": MaltaGeography.vector(MaltaGeography.data().landmarks.filter(func(marker): return marker.name == "Mdina")[0].position)}
	for key in sites:
		await _overhead(camera, sites[key], 820, destination.path_join(key + "-overhead.jpg"))
		await _oblique(camera, sites[key], Vector3(.45, 0, 1).normalized(), 365, destination.path_join(key + "-oblique.jpg"))
	quit()


func _aim_height(district: WartimeDistrict) -> float:
	var model: WartimeChurch = district.churches.get(district.record.id)
	if model != null:
		return model.global_position.y
	if not district.house_positions.is_empty():
		var position: Vector3 = district.house_positions.values()[0]
		return position.y
	return 85.0


func _overhead(camera: Camera3D, center: Vector3, span: float, path: String) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(span * 1.09, 180)
	camera.position = center + Vector3.UP * 1700
	camera.look_at(center, Vector3.FORWARD)
	await _save(path)


func _oblique(camera: Camera3D, center: Vector3, direction: Vector3, distance: float, path: String) -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 43
	camera.position = center + direction * distance + Vector3.UP * distance * .55
	camera.look_at(center + Vector3.UP * 8)
	await _save(path)


func _save(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_jpg(path, .88)
	if error != OK:
		push_error("Could not save " + path)
	else:
		print("Captured ", path)

func _measure(camera: Camera3D, center: Vector3) -> void:
	for altitude in [55, 600]:
		camera.position = center + Vector3(74, altitude, 256)
		camera.look_at(center)
		for i in 5:
			await RenderingServer.frame_post_draw
		var start := Time.get_ticks_usec()
		for i in 20:
			await RenderingServer.frame_post_draw
		print("Qormi camera +%dm: %.1f ms/frame, software renderer" % [altitude, (Time.get_ticks_usec() - start) / 20000.0])
