extends SceneTree
## Real engine streams and native mixer. Disclosed frozen/relocated aircraft and
## deterministic motion samples isolate acoustics; no manual flyby is claimed.
var checks: int = 0
var failures: int = 0
var stage: Node3D
var camera: Camera3D
var enemy: EnemyAircraft
var flyby: EnemyFlybyAudio
var capture: AudioEffectCapture
var measurements: Dictionary = {}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var mixer: GameAudioMixer = GameAudioMixer.instance
	var saved_volumes: Dictionary = mixer.volumes.duplicate()
	var saved_mute: bool = mixer.muted
	mixer.playback_enabled = true
	mixer.set_menu_active(false)
	mixer.set_muted(false, false)
	mixer.set_volume("Aircraft", .75, false)
	stage = Node3D.new()
	root.add_child(stage)
	root.set_as_audio_listener_3d(true)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.position.y = 300
	camera.make_current()
	enemy = spawn_enemy()
	await frames(4)
	freeze_enemy(enemy)
	flyby = enemy.aircraft_audio.flyby
	check(flyby != null and flyby.profile == preload("res://audio_profiles/enemy_flyby.tres"), "Every enemy receives the shared configurable flyby component")
	check(flyby.airflow.stream == null and not flyby.airflow.playing, "Missing airflow recording stays silent with an exposed asset slot")
	check(enemy.aircraft_audio.idle.doppler_tracking == AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED and enemy.aircraft_audio.flight.doppler_tracking == AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED, "Custom enemy Doppler explicitly disables built-in Doppler")
	check(flyby.airflow.bus == "Aircraft" and enemy.aircraft_audio.idle.attenuation_model == AudioStreamPlayer3D.ATTENUATION_DISABLED, "Engine and airflow share existing radio/pause bus without double attenuation")
	var player := FlightAircraft.new()
	stage.add_child(player)
	await frames(2)
	player.freeze = true
	player.engine_running = false
	check(player.aircraft_audio.flyby == null and player.aircraft_audio.idle.unit_size == 12, "Player engine implementation retains its existing tuning")
	capture = AudioEffectCapture.new()
	capture.buffer_length = 1
	var bus: int = AudioServer.get_bus_index("Aircraft")
	AudioServer.add_bus_effect(bus, capture)
	place_source(Vector3(0, 300, -1800), Vector3.ZERO)
	await frames(240)
	var far: Dictionary = await measure()
	var far_gain: float = flyby.distance_gain
	var far_fullness: float = flyby.fullness
	place_source(Vector3(0, 300, -50), Vector3.ZERO)
	await frames(160)
	var near: Dictionary = await measure()
	measurements.far = far
	measurements.near = near
	check(far.rms > .00001 and near.rms > far.rms * 5, "Real native engine samples grow from distant drone to strong close roar")
	check(flyby.distance_gain > far_gain * 10 and flyby.fullness > far_fullness + .7, "Proximity increases level and full engine timbre independently of RPM")
	check(flyby.airflow_gain < .001, "Stationary nearby aircraft does not generate airflow")
	var pitch: float = enemy.aircraft_audio.idle.pitch_scale
	enemy.pilot.throttle = .1
	await frames(120)
	check(enemy.aircraft_audio.idle.pitch_scale < pitch and enemy.aircraft_audio.rpm < .5, "Engine RPM still responds independently to throttle")
	enemy.pilot.throttle = .75
	await frames(120)
	var rpm: float = enemy.aircraft_audio.rpm
	# Deterministic trajectories use the same acoustic update; isolate it from
	# the live observer until the camera/transition checks below.
	flyby.set_physics_process(false)
	for i in range(120): flyby.update_motion(Vector3(0, 300, -100), Vector3(0, 0, 110), camera.position, Vector3.ZERO, 1.0/120)
	await frames(2)
	var approaching: float = flyby.doppler_factor
	var arriving_air: float = flyby.airflow_gain
	check(approaching > 1.2 and approaching <= flyby.profile.maximum_doppler_pitch, "Approaching engine shifts up with a bounded relative-motion Doppler factor")
	check(arriving_air > .5 and not flyby.airflow.playing, "Close fast pass builds airflow envelope but missing asset never plays fake sound")
	for i in range(120): flyby.update_motion(Vector3(0, 300, 100), Vector3(0, 0, 110), camera.position, Vector3.ZERO, 1.0/120)
	await frames(2)
	check(flyby.doppler_factor < .85 and flyby.doppler_factor >= flyby.profile.minimum_doppler_pitch and flyby.doppler_factor < approaching, "Receding engine drops pitch without altering engine RPM")
	check(absf(enemy.aircraft_audio.rpm - rpm) < .01, "Doppler does not feed back into throttle/RPM")
	var before: float = flyby.airflow_gain
	flyby.update_motion(Vector3(0, 300, 900), Vector3(0, 0, 110), camera.position, Vector3.ZERO, 1.0/120)
	check(flyby.airflow_gain > before * .9 and flyby.airflow_gain < before, "Airflow tail releases continuously instead of abrupt cutoff")
	for i in range(480): flyby.update_motion(Vector3(0, 300, -40), Vector3(90, 0, 0), camera.position, Vector3(90, 0, 0), 1.0/120)
	check(flyby.airflow_gain < .01 and absf(flyby.doppler_factor - 1) < .001, "Nearby matched-speed aircraft has no sustained whoosh or artificial Doppler")
	for i in range(120): flyby.update_motion(Vector3(0, 300, -1300), Vector3(0, 0, 110), camera.position, Vector3.ZERO, 1.0/120)
	check(flyby.airflow_gain < .003 and flyby.distance_gain < .1, "Distant fast pass retains quiet engine and negligible close-pass envelope")
	for i in range(120): flyby.update_motion(Vector3(0, 300, -40), Vector3(0, 0, 10000), camera.position, Vector3(0, 0, -10000), 1.0/120)
	check(flyby.doppler_factor <= flyby.profile.maximum_doppler_pitch and is_finite(flyby.doppler_factor), "Extreme motion cannot create runaway/invalid pitch")
	# Diagnostic sine wave only verifies the exposed asset hook and looping.
	# It is never assigned to production tuning or presented as rushing air.
	var profile: AircraftFlybyProfile = flyby.profile.duplicate() as AircraftFlybyProfile
	profile.airflow_stream = diagnostic_stream()
	flyby.profile = profile
	flyby.configure_sources()
	for i in range(120): flyby.update_motion(Vector3(0, 300, -30), Vector3(0, 0, 110), camera.position, Vector3.ZERO, 1.0/120)
	await frames(30)
	check(flyby.airflow.playing and flyby.airflow.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and flyby.airflow_starts == 1, "Assigned test stream uses one continuous looping airflow voice")
	await frames(120)
	check(flyby.airflow_starts == 1, "Holding a close-pass envelope never restarts airflow every frame")
	flyby.profile = preload("res://audio_profiles/enemy_flyby.tres")
	flyby.configure_sources()
	check(not flyby.airflow.playing and flyby.airflow.stream == null, "Removing test clip restores truly missing/silent airflow state")
	flyby.clear()
	flyby.set_physics_process(true)
	place_source(Vector3(-60, 300, -70), Vector3.ZERO)
	await frames(150)
	var left: Dictionary = await measure()
	place_source(Vector3(60, 300, -70), Vector3.ZERO)
	await frames(120)
	var right: Dictionary = await measure()
	measurements.left = left
	measurements.right = right
	check(left.left_rms > left.right_rms * 1.2 and right.right_rms > right.left_rms * 1.2, "Actual native stereo energy follows a crossing from left to right")
	var replacement := Camera3D.new()
	stage.add_child(replacement)
	replacement.position = Vector3(800, 310, 300)
	replacement.make_current()
	await frames(2)
	check(flyby.listener_id == replacement.get_instance_id() and flyby.listener_velocity.length() < 1 and absf(flyby.doppler_factor - 1) < .1, "Camera switch resets listener motion instead of creating a pitch/airflow spike")
	check(flyby.airflow_gain < .001, "Camera transition alone cannot generate a strong close pass")
	var explicit_listener := AudioListener3D.new()
	stage.add_child(explicit_listener)
	explicit_listener.position = Vector3(0, 300, 0)
	explicit_listener.make_current()
	await frames(4)
	check(flyby.listener_id == explicit_listener.get_instance_id(), "An explicitly active AudioListener3D takes priority over camera fallback")
	explicit_listener.clear_current()
	camera.make_current()
	await frames(90)
	var extra: Array[EnemyAircraft] = []
	for i in range(2):
		var foe: EnemyAircraft = spawn_enemy()
		extra.append(foe)
	await frames(3)
	for i in range(extra.size()):
		freeze_enemy(extra[i])
		extra[i].global_position = Vector3((i * 2 - 1) * 25, 300, -55)
	place_source(Vector3(0, 300, -50), Vector3.ZERO)
	await frames(180)
	var budget: float = 0
	for voice in get_nodes_in_group("enemy_flyby_audio"): budget += voice.estimated_peak() * voice.crowd_gain
	var cluster: Dictionary = await measure()
	measurements.cluster = cluster
	check(budget <= flyby.profile.enemy_peak_budget + .001 and flyby.crowd_gain < 1, "Multiple close aircraft share a bounded source-level peak budget")
	check(cluster.rms > .001 and cluster.peak < .95, "Actual summed native samples remain audible without clipping")
	var owner := Node.new()
	stage.add_child(owner)
	var bus_before: float = AudioServer.get_bus_volume_db(bus)
	check(mixer.begin_radio(owner, -4) and is_equal_approx(AudioServer.get_bus_volume_db(bus), bus_before - 4), "Existing radio duck attenuates engine and airflow together")
	mixer.end_radio(owner)
	check(is_equal_approx(AudioServer.get_bus_volume_db(bus), bus_before), "Radio completion restores the previous aircraft bus level")
	enemy.components.integrity[&"engine"] = 0
	await frames(100)
	check(not enemy.aircraft_audio.idle.playing and not enemy.aircraft_audio.flight.playing, "Failed engine fades and stops both engine layers")
	enemy.components.integrity[&"engine"] = 80
	await frames(100)
	check(enemy.aircraft_audio.idle.playing, "Restored live power can resume engine loops")
	enemy.take_damage(1000)
	await frames(3)
	check(not enemy.aircraft_audio.idle.playing and not flyby.airflow.playing and flyby.airflow_gain == 0, "Destruction clears engine and airflow immediately")
	var old_voice_count: int = get_nodes_in_group("enemy_flyby_audio").size()
	extra[0].queue_free()
	await frames(3)
	check(get_nodes_in_group("enemy_flyby_audio").size() == old_voice_count - 1, "Removing aircraft removes its voices and shared budget contribution")
	print("FLYBY NATIVE MEASUREMENTS: ", JSON.stringify(measurements))
	AudioServer.remove_bus_effect(bus, AudioServer.get_bus_effect_count(bus)-1)
	if is_instance_valid(AircraftImpactService.instance): AircraftImpactService.instance.clear_all()
	stage.queue_free()
	await frames(4)
	# Let the actual audio thread retire stopped Ogg playbacks before quitting.
	OS.delay_msec(200)
	await frames(4)
	for name in saved_volumes: mixer.set_volume(name, saved_volumes[name], false)
	mixer.set_muted(saved_mute, false)
	print("FLYBY AUDIO RESULT: ", checks-failures, "/", checks, " passed; ", failures, " failed")
	call_deferred("quit", 1 if failures else 0)

func spawn_enemy() -> EnemyAircraft:
	var foe := EnemyAircraft.new()
	stage.add_child(foe)
	return foe

func freeze_enemy(foe: EnemyAircraft) -> void:
	foe.freeze = true
	foe.reset_pending = false
	foe.ai.set_physics_process(false)
	foe.rear_gunner.set_physics_process(false)
	foe.rear_gunner.cease_fire()
	foe.pilot.automated = true
	foe.pilot.throttle = .75
	foe.global_basis = Basis.IDENTITY
	foe.angular_velocity = Vector3.ZERO

func place_source(point: Vector3, velocity: Vector3) -> void:
	enemy.global_position = point - enemy.aircraft_audio.position
	enemy.linear_velocity = velocity

func diagnostic_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(4410 * 2)
	for i in range(4410): data.encode_s16(i*2, roundi(sin(TAU * 440 * i/22050.0) * 1000))
	stream.data = data
	return stream

func measure() -> Dictionary:
	# Flush previous gain/pan states from the real mixer, then collect samples.
	OS.delay_msec(180)
	await frames(3)
	capture.clear_buffer()
	OS.delay_msec(140)
	await frames(3)
	var samples: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
	var energy := Vector2.ZERO
	var peak: float = 0
	for sample in samples:
		energy += sample * sample
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	var l: float = sqrt(energy.x / maxf(samples.size(), 1))
	var r: float = sqrt(energy.y / maxf(samples.size(), 1))
	return {"frames":samples.size(), "rms":sqrt((l*l+r*r)*.5), "left_rms":l, "right_rms":r, "peak":peak}

func frames(count: int) -> void:
	for tick in range(count): await physics_frame

func check(value: bool, message: String) -> void:
	checks += 1
	if value: print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
