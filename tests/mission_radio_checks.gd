extends SceneTree
## Actual supplied voice and Dummy mixer. No synthesized speech/test tone.
var checks: int = 0
var failures: int = 0
var session: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var mixer: GameAudioMixer = GameAudioMixer.instance
	var saved_volumes: Dictionary = mixer.volumes.duplicate()
	var saved_muted: bool = mixer.muted
	mixer.playback_enabled = true
	mixer.set_muted(false, false)
	for bus in ["Aircraft", "Guns"]:
		mixer.set_volume(bus, 0.6, false)
	var capture: AudioEffectCapture = AudioEffectCapture.new()
	capture.buffer_length = 1
	AudioServer.add_bus_effect(0, capture)
	session = preload("res://main.tscn").instantiate()
	root.add_child(session)
	await _frames(3)
	session.start_interception("spitfire")
	await _frames(6)
	var mission: VallettaInterception = session.interception
	var radio: MissionRadio = mission.radio
	_check(radio.voice_clip != null and absf(radio.voice_clip.get_length() - 3.831) < 0.05, "Mission assigns the supplied complete commander recording")
	_check(not radio.triggered and not radio.player.playing and not radio.subtitle.visible and mixer.radio_owner == 0, "Ground/checkpoint phase has no speech, subtitle or audio ducking")
	var source_loop: bool = (radio.voice_clip as AudioStreamOggVorbis).loop
	preload("res://tests/interception_fixture.gd").prepare_final_entry(session)
	# Nose and velocity differ: clock direction must still use aircraft heading.
	session.aircraft.pending_reset_velocity = session.aircraft.pending_reset_velocity.rotated(Vector3.UP, deg_to_rad(20))
	await _frames(6)
	_check(mission.activated and radio.triggered and radio.transmissions_played == 1 and radio.player.playing, "Final checkpoint activates one formation and one real voice playback")
	_check(radio.subtitle.visible and radio.subtitle.text.contains(MissionRadio.FORMATION_LINE) and mission.objective.text.contains(MissionRadio.FORMATION_LINE), "Matching warning and commander subtitle appear during playback")
	_check(radio.player is AudioStreamPlayer and radio.player.bus == "Master" and radio.player.volume_db == mission.definition.commander_volume_db, "Player radio is non-spatial with consistent gain independent of enemy distance")
	_check(absf(mission.activation_bearing - 30) < 0.001 and absf(mission.activation_distance - 2500) < 1, "Formation is measured 30 degrees right and 2500 metres away")
	_check(not (radio.player.stream as AudioStreamOggVorbis).loop and (radio.voice_clip as AudioStreamOggVorbis).loop == source_loop, "Transmission is non-looping without mutating imported voice")
	for bus in ["Aircraft", "Guns"]:
		_check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus)) - (linear_to_db(0.6) - 4)) < 0.001 and mixer.volumes[bus] == 0.6, bus + " ducks by 4 dB without overwriting saved volume")
	for index in range(5):
		mission.activate()
		radio.transmit_formation()
	_check(radio.transmissions_played == 1 and session.encounters.active.size() == 2, "Repeated activation cannot overlap speech or duplicate enemies")
	var competing: MissionRadio = MissionRadio.new()
	competing.voice_clip = radio.voice_clip
	root.add_child(competing)
	competing.transmit_formation()
	_check(competing.transmissions_played == 0 and not competing.subtitle.visible, "Busy player radio blocks overlapping transmissions")
	competing.stop()
	_check(mixer.radio_owner == radio.get_instance_id(), "Stopping a blocked transmission cannot unduck an active call")
	competing.queue_free()
	mixer.set_volume("Aircraft", 0.42, false)
	_check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Aircraft")) - (linear_to_db(0.42) - 4)) < 0.001, "Changing user volume mid-transmission retains the duck overlay")
	# Dummy audio consumes real wall-clock buffers, not fixed-fps simulated time.
	mixer.music.stop()
	capture.clear_buffer()
	OS.delay_msec(200)
	await _frames(3)
	var energy: float = 0
	var samples: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
	for sample in samples:
		energy += sample.length_squared()
	_check(samples.size() > 0 and sqrt(energy / maxf(samples.size() * 2, 1)) > 0.001, "Supplied voice produces real nonzero native mixer samples")
	for index in range(240):
		# The audio thread stops first; AudioStreamPlayer.finished is delivered
		# on the next idle tick. Wait for the actual cleanup, not only playing.
		if not radio.player.playing and not radio.subtitle.visible and mixer.radio_owner == 0:
			break
		OS.delay_msec(20)
		await _frames(1)
	_check(not radio.player.playing and not radio.subtitle.visible and mixer.radio_owner == 0, "Natural clip completion hides subtitle and releases ducking")
	_check(absf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Aircraft"))) - 0.42) < 0.001 and absf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Guns"))) - 0.6) < 0.001, "Completion restores current user engine/gun levels")
	radio.transmit_formation()
	_check(radio.transmissions_played == 1 and not radio.player.playing, "Completed transmission cannot replay in the same mission")
	session.restart_malta()
	await _frames(6)
	mission = session.interception
	radio = mission.radio
	_check(not radio.triggered and radio.transmissions_played == 0 and mixer.radio_owner == 0, "Mission retry resets the radio trigger and removes previous playback")
	preload("res://tests/interception_fixture.gd").prepare_final_entry(session)
	await _frames(6)
	_check(radio.transmissions_played == 1 and radio.player.playing, "A fresh mission can transmit once again")
	mission.cancel()
	_check(not radio.player.playing and not radio.subtitle.visible and mixer.radio_owner == 0, "Cancelling an active mission immediately stops speech and restores mix")
	session.restart_malta()
	await _frames(6)
	preload("res://tests/interception_fixture.gd").prepare_final_entry(session)
	await _frames(6)
	radio = session.interception.radio
	session.return_to_missions()
	_check(not radio.player.playing and not radio.subtitle.visible and mixer.radio_owner == 0, "Leaving the mission cancels its transmission before removing the world")
	await _frames(3)
	var missing: MissionRadio = MissionRadio.new()
	root.add_child(missing)
	missing.transmit_formation()
	missing.transmit_formation()
	_check(missing.missing_asset and missing.triggered and missing.transmissions_played == 0 and not missing.player.playing and not missing.subtitle.visible and mixer.radio_owner == 0, "Missing asset remains silent without fake speech/subtitles or ducking")
	missing.queue_free()
	session.queue_free()
	await _frames(3)
	for bus in saved_volumes:
		mixer.set_volume(bus, saved_volumes[bus], false)
	mixer.set_muted(saved_muted, false)
	mixer.set_menu_active(false)
	mixer.music.stop()
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	OS.delay_msec(150)
	await _frames(6)
	print("MISSION RADIO RESULT: ", checks - failures, "/", checks, " passed")
	quit(1 if failures else 0)

func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame

func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
