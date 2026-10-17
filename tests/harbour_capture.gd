extends SceneTree
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func capture(name: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	print("CAPTURE ",name," ",root.get_texture().get_image().save_png("res://docs/previews/"+name+".png"))
func run() -> void:
	var session = preload("res://main.tscn").instantiate()
	root.add_child(session)
	GameAudioMixer.instance.playback_enabled = false
	session.show_missions()
	session.missions_menu.mission_picker.select(2)
	session.missions_menu._choose_mission(2)
	await capture("harbour-mission-menu")
	session.start_harbour()
	await frames(70)
	session.malta_mission.board_nearest()
	await capture("harbour-faith-ground")
	var mission: HarbourInterception = session.harbour
	mission.phase = "SPAWNING"
	mission._spawn_wave()
	await frames(3)
	# Staged preview only: inspect the real meshes/markers, not a flown encounter.
	session.aircraft.freeze = true
	for friend in mission.wingmen: friend.freeze = true; friend.ai.set_physics_process(false)
	for foe in mission.roster.active: foe.freeze = true; foe.ai.set_physics_process(false)
	var camera := Camera3D.new()
	session.add_child(camera)
	camera.far = 50000
	camera.fov = 55
	camera.make_current()
	camera.global_position = mission.bomber.global_position + Vector3(90,70,180)
	camera.look_at(mission.bomber.global_position)
	session.hud.hide()
	session.malta_mission.status.hide()
	GameAudioMixer.instance.audio_button.hide()
	await capture("harbour-formation")
	session.queue_free()
	await frames(5)
	quit()
