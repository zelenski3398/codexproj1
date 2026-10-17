extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ",text)
func _run() -> void:
	var mixer: GameAudioMixer = root.get_node("GameAudio")
	mixer.playback_enabled = true # Dummy audio device: lifecycle, not listening test.
	var before: Dictionary = mixer.volumes.duplicate()
	var radio := MissionRadioQueue.new()
	radio.definition = preload("res://mission_definitions/harbour.tres")
	root.add_child(radio)
	radio.set_process(false)
	radio.cue("intro","Opening briefing",radio.definition.intro_voice,true)
	radio.cue("intro","Duplicate",radio.definition.intro_voice)
	radio._process(0)
	check(radio.played == ["intro"] and radio.current_id == "intro", "Supplied introduction starts exactly once")
	check(radio.player is AudioStreamPlayer and radio.player.bus == "Master" and radio.player.max_polyphony == 1, "Non-positional player radio uses single channel")
	check(radio.player.stream is AudioStreamOggVorbis and not radio.player.stream.loop and radio.player.stream.get_length() > 19, "Real supplied introduction, non-looping")
	check(mixer.radio_owner == radio.get_instance_id() and mixer.radio_duck_db == -4, "Engine and weapon buses duck during supplied voice")
	check(radio.caption.visible and radio.caption.text.begins_with("COMMANDER · recording summary"), "Recorded-call caption explicitly marked as summary")
	radio.cue("wave_1","Formation approaching")
	radio._process(.1)
	check(radio.current_id == "intro" and radio.pending.size() == 1, "Detection cue queues instead of overlapping briefing")
	radio.player.finished.emit()
	check(mixer.radio_owner == 0 and mixer.radio_duck_db == 0 and mixer.volumes == before, "Finish restores previous bus settings exactly")
	radio._process(0)
	check(radio.current_id == "wave_1" and radio.caption.text.ends_with("[subtitle only]") and radio.player.stream == null and mixer.radio_owner == 0, "Missing wave voice uses labelled subtitle, no fake speech or ducking")
	radio.cue("success","Congratulations",radio.definition.success_voice,true,true)
	radio._process(0)
	check(radio.played == ["intro","success"] and radio.current_id == "success" and radio.pending.is_empty(), "Success recording preempts obsolete cues exactly once")
	check(radio.player.stream.get_length() > 14 and not radio.player.stream.loop, "Supplied congratulations recording plays once")
	radio.cue("success","Duplicate",radio.definition.success_voice)
	check(radio.pending.is_empty(), "Repeated result cannot repeat congratulations")
	radio.stop()
	check(not radio.player.playing and radio.player.stream == null and not radio.caption.visible and mixer.radio_owner == 0, "Leaving stops playback, subtitles and ducking")
	radio.cue("late","Should not play")
	check(radio.pending.is_empty(), "Cancelled mission rejects delayed transmissions")
	radio.queue_free()
	for i in 5: await physics_frame
	print("HARBOUR RADIO RESULT: ", checks - failures,"/",checks," passed")
	# Let the threaded audio server release stopped decoder buffers before teardown.
	OS.delay_msec(200)
	quit(1 if failures else 0)
