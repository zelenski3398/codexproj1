extends SceneTree
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	print("CAPTURE ",label,": ",root.get_texture().get_image().save_png("res://docs/previews/intro-"+label+".png"))
func run() -> void:
	var session = preload("res://main.tscn").instantiate()
	root.add_child(session)
	await create_timer(0.7).timeout
	await capture("opening")
	await create_timer(3.8).timeout
	var intro: GameIntro = session.startup_intro
	print("VIDEO_POSITION=",intro.movie.stream_position," PLAYING=",intro.movie.is_playing())
	await capture("poster")
	await create_timer(2).timeout
	print("LOOP_POSITION=",intro.movie.stream_position," PLAYING=",intro.movie.is_playing())
	# Click actual integrated button through the viewport input pipeline.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = intro.poster_rect.position + intro.play_button.position + intro.play_button.size * 0.5
	click.pressed = true
	root.push_input(click, true)
	await frames(2)
	click.pressed = false
	root.push_input(click, true)
	await create_timer(3.8).timeout
	print("MENU_READY=",session.startup_intro == null and session.selector.active)
	await capture("menu")
	GameAudioMixer.instance.set_menu_active(false)
	GameAudioMixer.instance.music.stop()
	GameAudioMixer.instance.music.stream = null
	session.queue_free()
	await frames(20)
	RenderingServer.force_sync()
	quit()
