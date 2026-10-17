extends SceneTree
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func capture(speaker: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	print("CAPTURE ",speaker," ",root.get_texture().get_image().save_png("res://docs/previews/radio-"+speaker+".png"))
func run() -> void:
	var session = preload("res://main.tscn").instantiate()
	root.add_child(session)
	GameAudioMixer.instance.playback_enabled = false
	session.start_harbour()
	await frames(70)
	session.malta_mission.board_nearest()
	var mission: HarbourInterception = session.harbour
	mission.set_physics_process(false)
	var radio: MissionRadioQueue = mission.radio
	radio.set_process(false)
	radio._end_current()
	radio.pending.clear()
	# Inject the actual bound key. No menu or pause is used for status requests.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_T
	key.keycode = KEY_T
	key.pressed = true
	Input.parse_input_event(key)
	await frames(2)
	key.pressed = false
	Input.parse_input_event(key)
	radio._process(0)
	print("KEY_REQUESTS=",mission.wingman_radio.request_number)
	await capture("faith")
	# Disclosed damaged-engine fixture immediately before the queued report.
	mission.wingmen[0].components.integrity[&"engine"] = 45
	radio._end_current(); radio._process(1)
	await capture("hope")
	radio._end_current(); radio._process(1)
	await capture("charity")
	session.queue_free()
	await frames(20)
	RenderingServer.force_sync()
	quit()
