extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var session = load("res://main.tscn").instantiate()
	root.add_child(session)
	for i in range(8): await process_frame
	session.start_malta("ta_qali","spitfire","interception")
	for i in range(20): await physics_frame
	var field: MaltaAirfield = session.field.fields.ta_qali
	var truck: MilitaryTruck = session.field.trucks[0]
	GameAudioMixer.instance.audio_button.hide()
	session.malta_mission.canvas.hide()
	session.interception.canvas.hide()
	var camera := Camera3D.new()
	session.add_child(camera)
	camera.global_position = truck.global_position + field.global_basis*Vector3(5,2.8,-5.5)
	camera.look_at(truck.global_position + Vector3.UP*1.1)
	camera.make_current()
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/military-truck.png")
	var gun: BritishAAGun = session.field.aa_battery.guns[1]
	camera.global_position = gun.global_position + field.global_basis*Vector3(8,4,9)
	camera.look_at(gun.global_position + Vector3.UP)
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/manual-aa-apron.png")
	quit()
