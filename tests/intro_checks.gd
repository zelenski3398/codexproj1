extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", label)
func run() -> void:
	var session = preload("res://main.tscn").instantiate()
	root.add_child(session)
	await frames(3)
	var selector = session.selector
	session.show_intro()
	var intro: GameIntro = session.startup_intro
	intro.set_process(false)
	check(not selector.active and session.aircraft == null, "Intro shields existing menu without starting gameplay")
	check(intro.movie.stream is VideoStreamTheora and intro.movie.loop and intro.movie.bus == &"Music", "Supplied movie uses looping Theora and existing Music bus")
	check(not GameAudioMixer.instance.menu_active and not GameAudioMixer.instance.audio_button.visible, "Menu music and floating audio control hidden during poster")
	for dimensions in [Vector2i(1440,900), Vector2i(480,900)]:
		root.content_scale_size = dimensions
		intro._layout()
		var button_rect := Rect2(intro.play_button.position, intro.play_button.size)
		check(Rect2(Vector2.ZERO,intro.poster_rect.size).encloses(button_rect), "Play remains inside poster at " + str(dimensions))
		check(is_equal_approx(intro.poster_rect.size.x / intro.poster_rect.size.y,834.0/1112.0), "Full uncropped portrait aspect preserved")
	intro.begin_play()
	check(intro.phase == GameIntro.Phase.OPENING, "Opening cannot accidentally launch menu")
	intro._process(4.1)
	check(intro.phase == GameIntro.Phase.POSTER and not intro.play_button.disabled, "Slow dissolve reveals usable printed Play panel")
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	Input.parse_input_event(key)
	await frames(2)
	check(intro.phase == GameIntro.Phase.LEAVING and session.aircraft == null, "Enter activates Play without launching aircraft")
	intro._process(0.5)
	var elapsed := intro.elapsed
	intro.begin_play()
	check(intro.elapsed == elapsed, "Repeated Play cannot restart transition")
	intro._process(1.2)
	check(intro.phase == GameIntro.Phase.MENU and not intro.surface.visible and not intro.movie.is_playing(), "Black midpoint stops video and reveals existing menu")
	check(GameAudioMixer.instance.menu_active and not selector.active, "Menu music returns while controls wait for fade")
	intro._process(1.7)
	await frames(2)
	check(session.startup_intro == null and session.selector == selector and selector.active, "Completion restores original menu exactly once")
	check(GameAudioMixer.instance.audio_button.visible, "Audio settings control restored")
	session.show_intro()
	var second: GameIntro = session.startup_intro
	second.set_process(false)
	second._process(4.1)
	var click := InputEventMouseButton.new()
	click.position = second.poster_rect.position + second.play_button.position + second.play_button.size * 0.5
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click, true)
	click.pressed = false
	root.push_input(click, true)
	check(second.phase == GameIntro.Phase.LEAVING, "Real pointer click on poster button begins transition")
	session.show_missions()
	await frames(2)
	check(session.startup_intro == null and session.missions_menu != null, "Programmatic navigation cancels intro safely")
	session.show_selection()
	check(session.startup_intro == null, "Returning to selection does not replay startup")
	session.queue_free()
	await frames(8)
	print("INTRO RESULT: ",checks-failures,"/",checks," passed")
	quit(1 if failures else 0)
