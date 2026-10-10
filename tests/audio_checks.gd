extends SceneTree
## Audio lifecycle against real menus, damage, successful gun salvos and Malta
## boarding. Dummy-driver playback state does not prove perceptual sound quality.
var checks: int = 0
var failures: int = 0
var world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	GameAudioMixer.instance.playback_enabled = true
	var previous_volumes: Dictionary = GameAudioMixer.instance.volumes.duplicate()
	var previous_mute: bool = GameAudioMixer.instance.muted
	GameAudioMixer.instance.set_muted(false, false)
	GameAudioMixer.instance.set_volume("Master", 0.8, false)
	GameAudioMixer.instance.set_volume("Music", 0.65, false)
	var capture: AudioEffectCapture = AudioEffectCapture.new()
	capture.buffer_length = 1
	AudioServer.add_bus_effect(0, capture)
	world = preload("res://main.tscn").instantiate()
	root.add_child(world)
	await _frames(120)
	OS.delay_msec(200) # Allow real mixer buffers, not only simulated frame time.
	await _frames(3)
	var samples: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
	var energy: float = 0
	for sample in samples:
		energy += sample.length_squared()
	_check(samples.size() > 0 and sqrt(energy / maxf(samples.size() * 2, 1)) > 0.001, "Native mixer decodes the supplied theme into nonzero audio samples")
	_check(GameAudioMixer.instance.menu_active and GameAudioMixer.instance.music.playing and GameAudioMixer.instance.music_gain > 0.99, "Startup plays and fades in the supplied menu theme")
	_check(GameAudioMixer.instance.music.stream.loop and absf(GameAudioMixer.instance.music.stream.get_length() - 83) < 0.1, "Complete 83-second theme loops without truncation")
	_check(AudioServer.get_bus_name(0) == "Master" and AudioServer.get_bus_index("Music") == 1 and AudioServer.get_bus_index("Aircraft") == 2 and AudioServer.get_bus_index("Guns") == 3, "Saved layout keeps Master and all playback buses in a stable order")
	_check(world.aircraft == null and world.enemy == null, "Menu preview has no live aircraft or engine sound")
	for bus in ["Master", "Music", "Aircraft", "Guns"]:
		GameAudioMixer.instance.set_volume(bus, 0.37, false)
		_check(absf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))) - 0.37) < 0.001, bus + " volume independently reaches its mixer bus")
	GameAudioMixer.instance.set_muted(true, false)
	_check(AudioServer.is_bus_mute(0), "Mute silences the master bus")
	GameAudioMixer.instance.set_muted(false, false)
	_check(not AudioServer.is_bus_mute(0), "Unmute restores audio without changing volumes")
	world.start_flight("spitfire")
	var plane: FlightAircraft = world.aircraft
	plane.freeze = true
	plane.pilot.automated = true
	world.enemy.ai.set_physics_process(false)
	await _frames(6) # Allow the enemy's initial physics reset before freezing.
	world.enemy.freeze = true
	await _frames(120)
	_check(not GameAudioMixer.instance.menu_active and not GameAudioMixer.instance.music.playing, "Departure fades out and stops menu music")
	_check(plane.aircraft_audio.idle.playing and plane.aircraft_audio.flight.playing and plane.aircraft_audio.flight_mix == 0, "Running engine at idle plays the idle layer, not flight timbre")
	_check(GameAudioMixer.instance.engine_stream(plane, false).resource_path == GameAudioMixer.instance.SPITFIRE_IDLE, "Spitfire uses its supplied engine recording")
	var idle_pitch: float = plane.aircraft_audio.idle.pitch_scale
	plane.pilot.throttle = 1
	await _frames(120)
	_check(plane.aircraft_audio.flight_mix > 0.99 and plane.aircraft_audio.idle.pitch_scale > idle_pitch, "Throttle smoothly increases flight timbre and RPM pitch")
	plane.components.apply_damage(&"engine", 20)
	await _frames(120)
	_check(plane.aircraft_audio.rpm < 0.9 and plane.aircraft_audio.flight_mix < 0.9, "Component engine power loss reduces sound RPM and flight blend")
	plane.engine_running = false
	await _frames(90)
	_check(not plane.aircraft_audio.idle.playing and not plane.aircraft_audio.flight.playing, "Engine shutdown fades both engine loops to silence")
	plane.engine_running = true
	await _frames(90)
	_check(plane.aircraft_audio.idle.playing, "Engine start restores the spatial engine sounds")
	plane.components.fuel_remaining = 0
	await _frames(90)
	_check(not plane.aircraft_audio.idle.playing and not plane.aircraft_audio.flight.playing, "Fuel exhaustion silences the powerless engine")
	plane.components.fuel_remaining = 1
	await _frames(90)
	paused = true
	for frame in range(5):
		await process_frame
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Aircraft")) and AudioServer.is_bus_mute(AudioServer.get_bus_index("Guns")), "Pause silences gameplay audio even with the settings UI active")
	paused = false
	await _frames(5)
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Aircraft")), "Resume restores gameplay buses")
	plane.guns.reset()
	plane.pilot.fire = false
	await _frames(3)
	plane.pilot.fire = true
	await _frames(45)
	_check(plane.guns.pool.total_spawned > 0 and plane.guns.weapon_audio.audible_salvos > 0 and plane.guns.weapon_audio.player.playing, "Successful eight-gun salvos drive one spatial gun voice")
	_check(plane.guns.weapon_audio.get_child_count() == 1, "Sustained firing allocates no per-bullet audio nodes")
	plane.pilot.fire = false
	await _frames(30)
	_check(not plane.guns.weapon_audio.player.playing, "Releasing the trigger stops the gun sound promptly")
	plane.guns.reset()
	await _frames(3)
	var heard: int = plane.guns.weapon_audio.audible_salvos
	plane.guns.shot_clearance = func(_point: Vector3, _direction: Vector3) -> bool: return false
	plane.pilot.fire = true
	await _frames(45)
	_check(not plane.guns.weapon_audio.player.playing and plane.guns.weapon_audio.audible_salvos == heard, "Obstructed shots do not produce false firing audio")
	plane.pilot.fire = false
	plane.guns.shot_clearance = Callable()
	plane.guns.reset()
	await _frames(3)
	plane.guns.pool.set_physics_process(false)
	for slot in range(plane.guns.pool.capacity):
		plane.guns.pool.spawn(plane.global_position, Vector3.FORWARD, 5, 0, plane.get_rid(), false, plane.team_id)
	plane.pilot.fire = true
	await _frames(30)
	_check(not plane.guns.weapon_audio.player.playing and plane.guns.weapon_audio.audible_salvos == heard and plane.guns.pool.dropped_rounds > 0, "Exhausted projectile pool cannot trigger a false gun sound")
	plane.pilot.fire = false
	plane.guns.reset()
	plane.guns.pool.set_physics_process(true)
	var rear: WingGuns = world.enemy.rear_gunner.guns
	world.enemy.rear_gunner.set_physics_process(false)
	rear.shot_clearance = func(_point: Vector3, _direction: Vector3) -> bool: return true
	rear.reset()
	rear.external_fire = false
	await _frames(3)
	rear.external_fire = true
	await _frames(30)
	_check(rear.weapon_audio.player.playing and rear.weapon_audio.audible_salvos > 0, "Stuka rear gun shares actual-salvo audio and its muzzle position")
	rear.external_fire = false
	await _frames(30)
	_check(not rear.weapon_audio.player.playing, "Rear-gunner burst rest stops its voice")
	rear.shot_clearance = Callable()
	plane.take_damage(100)
	await _frames(3)
	_check(plane.is_destroyed and not plane.aircraft_audio.idle.playing and not plane.guns.weapon_audio.player.playing, "Destruction stops engine and guns immediately")
	plane.freeze = false
	plane.request_reset()
	await _frames(120)
	_check(not plane.is_destroyed and plane.health.hp == 100 and plane.aircraft_audio.idle.playing and not plane.guns.weapon_audio.player.playing, "Reset restores engine and health without stray gun sounds")
	world.show_selection()
	await _frames(120)
	_check(GameAudioMixer.instance.music.playing and world.aircraft == null and world.enemy == null, "Return to selection resumes one theme and removes old aircraft voices")
	world.start_flight("sea_gladiator")
	await _frames(60)
	_check(GameAudioMixer.instance.engine_stream(world.aircraft, false).resource_path == GameAudioMixer.instance.GLADIATOR_IDLE and GameAudioMixer.instance.gun_stream(world.aircraft).resource_path == GameAudioMixer.instance.GLADIATOR_GUNS, "Sea Gladiator uses its own radial-engine and gun recordings")
	world.show_selection()
	await _frames(3)
	var playback: float = GameAudioMixer.instance.music.get_playback_position()
	world.show_malta_selection()
	await _frames(30)
	_check(GameAudioMixer.instance.menu_active and GameAudioMixer.instance.music.playing and GameAudioMixer.instance.music.get_playback_position() >= playback, "Moving to the departure map keeps the same theme playing")
	world.start_malta("ta_qali", "spitfire")
	await _frames(120)
	var mission: MaltaMission = world.malta_mission
	var parked_silent: bool = true
	for parked in mission.fleet:
		parked_silent = parked_silent and not parked.aircraft_audio.idle.playing
	_check(parked_silent and not GameAudioMixer.instance.music.playing, "Malta departure keeps all six parked engines silent and stops menu music")
	mission.board_nearest()
	await _frames(5)
	_check(mission.occupied != null and not mission.occupied.aircraft_audio.idle.playing, "Boarding does not start an engine or reset its state")
	_key(KEY_I)
	await _frames(90)
	_check(mission.occupied.engine_running and mission.occupied.aircraft_audio.idle.playing, "Malta I starts the boarded aircraft's engine sound")
	_key(KEY_I)
	await _frames(90)
	mission.leave_aircraft()
	await _frames(10)
	_check(mission.occupied == null and not mission.initial_aircraft.aircraft_audio.idle.playing, "Shutdown and exit leave the persistent parked aircraft silent")
	world.show_selection()
	world.queue_free()
	await _frames(3)
	for bus in previous_volumes:
		GameAudioMixer.instance.set_volume(bus, previous_volumes[bus], false)
	GameAudioMixer.instance.set_muted(previous_mute, false)
	GameAudioMixer.instance.set_menu_active(false)
	GameAudioMixer.instance.music.stop()
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	# Fixed-fps tests run faster than the audio thread's wall-clock buffers.
	# Let it release cancelled stream playbacks before shutting down Godot.
	OS.delay_msec(150)
	await _frames(6)
	print("AUDIO RESULT: ", checks - failures, "/", checks, " passed")
	quit(1 if failures else 0)

func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame

func _key(code: int) -> void:
	for pressed in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
