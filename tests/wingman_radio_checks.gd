extends SceneTree
var session: Node3D
var mission: HarbourInterception
var radio: MissionRadioQueue
var wing: WingmanRadio
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await physics_frame
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", text)
func drain_current() -> void:
	radio._end_current()
	radio._process(1)
func place(plane: FlightAircraft, point: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	plane.freeze = true
	plane.reset_pending = false
	plane.global_transform = Transform3D(basis, point)
	plane.linear_velocity = -basis.z * 50
	plane.pilot.fire = false
	if plane is EnemyAircraft: plane.ai.set_physics_process(false)
	if plane is FriendlyGladiator:
		plane.ai.set_physics_process(false)
		plane.ai.departed = true
		plane.ai.takeoff_hold = false
func run() -> void:
	session = preload("res://main.tscn").instantiate()
	root.add_child(session)
	session.start_harbour()
	await frames(180)
	mission = session.harbour
	radio = mission.radio
	wing = mission.wingman_radio
	radio.set_process(false)
	wing.set_physics_process(false)
	for spotter in wing.spotters.values(): spotter.set_physics_process(false)
	check(InputMap.has_action("wingman_status") and WingmanRadio.binding_text().contains("T"), "Status action has discoverable default T binding")
	var original_events: Array[InputEvent] = InputMap.action_get_events("wingman_status")
	InputMap.action_erase_events("wingman_status")
	var alternate := InputEventKey.new()
	alternate.physical_keycode = KEY_Y
	InputMap.action_add_event("wingman_status", alternate)
	check(WingmanRadio.binding_text().contains("Y"), "Discoverable radio binding reflects Input Map remapping")
	InputMap.action_erase_events("wingman_status")
	for event in original_events: InputMap.action_add_event("wingman_status", event)
	check(mission.wingman_radio != null and wing.spotters.size() == 2, "Each friendly has isolated perception memory")
	check(session.malta_mission.board_nearest(), "Existing boarding still works")
	radio._end_current()
	radio.pending.clear()
	var mixer := GameAudioMixer.instance
	mixer.playback_enabled = true # Dummy device lifecycle; no listening claim.
	var hope: FriendlyGladiator = mission.wingmen[0]
	var charity: FriendlyGladiator = mission.wingmen[1]
	place(session.aircraft, Vector3(9000,1000,8500))
	place(hope, Vector3(9050,1000,8550))
	place(charity, Vector3(8950,1000,8550))
	mission.set_physics_process(false)
	mission.phase = "SPAWNING"
	mission._spawn_wave()
	for foe in session.encounters.active: place(foe, Vector3(15000,1500,15000))
	var foe: EnemyAircraft = mission.escorts[0]
	place(foe, Vector3(9500,1000,8500))
	await frames(3)
	radio.pending.clear() # isolate status request from the wave detection cue
	check(wing.request_status(), "One request accepted during flight without pausing")
	for i in 10: wing.request_status()
	check(radio.pending.size() == 4 and wing.request_number == 1 and not paused, "Repeated requests do not stack or pause simulation")
	radio._process(0)
	check(radio.current_entry.speaker == "FAITH" and radio.caption.text.contains(WingmanRadio.REQUEST_LINE), "Faith transmits the requested status line first")
	check(radio.player.stream != null and radio.played.back().ends_with("Faith"), "Faith uses supplied request recording")
	check(mixer.radio_owner == radio.get_instance_id(), "Player transmission owns shared ducked channel")
	hope.take_damage(40)
	hope.components.integrity[&"engine"] = 35
	hope.ai.target = foe
	var hope_spotter: WingmanSpotter = wing.spotters.Hope
	hope_spotter.scan()
	check(hope_spotter.visible.size() == 1, "Range/FOV detector sees one spawned hostile and no future waves")
	drain_current()
	check(radio.current_entry.speaker == "HOPE" and radio.caption.text.contains("engine damaged"), "Hope's condition is sampled at reply time, after queued damage")
	check(radio.caption.text.contains("Engaging a fighter") and radio.caption.text.contains("CR.42") and not radio.caption.text.contains("HP"), "Report matches visible target/activity without enemy HP")
	check(radio.caption.text.contains("your 3 o'clock"), "Clock bearing is relative to Faith, not reporting pilot")
	check(radio.player.stream != null, "Hope uses her assigned neutral identification voice")
	var hope_audio_length: float = radio.player.stream.get_length()
	# Change Charity after request, before she speaks.
	charity.take_damage(76)
	charity.ai.mode = "EVADE"
	charity.ai.terrain_avoiding = false
	drain_current()
	check(radio.current_entry.speaker == "CHARITY" and radio.caption.text.contains("Critical damage") and radio.caption.text.contains("fire on board") and radio.caption.text.contains("Evading"), "Charity reports live critical damage, fire and evasion")
	check(radio.player.stream != null and not is_equal_approx(radio.player.stream.get_length(),hope_audio_length), "Charity and Hope have distinct supplied voice assets")
	drain_current()
	check(not radio.has_group("wingman_status"), "No response message skipped while survivor replies exist")
	check(not wing.request_status(), "Configurable cooldown rejects another finished request")
	wing.cooldown = 0
	# Spotting memory snapshots cannot follow an enemy that leaves view.
	var old: Vector3 = foe.global_position
	place(foe, Vector3(16000,1000,16000))
	hope_spotter.clock += 1
	hope_spotter.scan()
	check(hope_spotter.visible.is_empty() and hope_spotter.sightings[foe.get_instance_id()].position == old, "Lost visual retains last known position, never tracks hidden movement")
	var report: Dictionary = wing._reply("Hope")
	check(report.text.contains("Last seen") and report.text.contains("lost visual"), "Recent memory explicitly distinguished from current sighting")
	hope_spotter.clock += mission.definition.radio_memory_seconds + 1
	check(wing._reply("Hope").text.contains("No enemy aircraft in sight"), "Old observations expire")
	place(foe, Vector3(9050,1000,9200))
	await frames(2)
	hope_spotter.scan()
	check(hope_spotter.visible.is_empty(), "Hostile behind wingman's field of view is not revealed")
	place(foe, Vector3(9050,1000,8050))
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80,80,20)
	shape.shape = box
	blocker.add_child(shape)
	session.add_child(blocker)
	blocker.global_position = Vector3(9050,1000,8300)
	await frames(3)
	hope_spotter.scan()
	check(hope_spotter.visible.is_empty(), "Terrain/building collision blocks line of sight")
	blocker.queue_free()
	await frames(3)
	hope_spotter.scan()
	check(hope_spotter.visible.has(foe.get_instance_id()), "Contact becomes visible when obstruction clears")
	session.aircraft.linear_velocity = Vector3.ZERO
	check(wing.bearing(Vector3(9500,1000,8500)) == "east", "Unreliable stationary heading uses plain compass direction")
	place(session.aircraft, session.aircraft.global_position, Basis(Vector3.UP,-PI/2))
	check(wing.bearing(Vector3(9500,1000,8500)) == "your 12 o'clock", "Clock bearing updates after Faith changes heading")
	# Sighted threat geometry, not enemy AI target assignment.
	place(session.aircraft, Vector3(9000,1000,8500))
	place(hope, Vector3(9050,1000,8550), Basis(Vector3.UP,PI))
	place(foe, Vector3(9000,1000,9000))
	foe.linear_velocity = Vector3(0,0,-85)
	await frames(3)
	var threat: Dictionary = wing._reply("Hope")
	check(threat.text.contains("threatening Faith") and threat.text.contains("your 6 o'clock"), "Observed heading and closure produce a truthful six-o'clock warning for Faith")
	var fort: Vector3 = mission.target_fort.global_position
	place(mission.bomber, fort + Vector3(0,500,1500))
	place(hope, fort + Vector3(0,500,1900))
	await frames(3)
	check(wing._reply("Hope").text.contains("approaching Fort St Elmo"), "Observed bomber approach reports its fort only when heading/visibility support it")
	place(hope, Vector3(9050,1000,8550))
	# Commander priority, interruption and speaker death.
	radio.cue("commander_fixture", "Commander briefing", mission.definition.intro_voice)
	radio._process(1)
	wing.request_status()
	radio._process(1)
	check(radio.current_id == "commander_fixture" and radio.has_group("wingman_status"), "Status waits behind commander recording without overlapping")
	radio.player.finished.emit()
	radio._process(1)
	radio.urgent_cue("test_urgent","Bomber lining up!")
	radio._process(1)
	check(radio.current_id == "test_urgent" and not radio.has_group("wingman_status"), "Urgent commander cue preempts routine report and pending replies")
	check(mixer.radio_owner == 0 and radio.player.stream == null, "Preemption stops supplied voice and restores ducking")
	radio._end_current()
	wing.cooldown = 0
	wing.request_status()
	radio._process(1)
	drain_current()
	check(radio.current_entry.speaker == "HOPE", "Live Hope begins reply")
	hope.take_damage(1000)
	check(radio.current_id == "" and not radio.player.playing, "Speaker destruction immediately stops active reply")
	radio._process(1) # commander loss warning may preempt status
	while radio.current_id != "": radio._end_current(); radio._process(1)
	wing.cooldown = 0
	wing.request_status()
	radio._process(1)
	drain_current()
	check(radio.current_entry.speaker == "CHARITY", "Only surviving Charity replies; destroyed Hope skipped")
	radio._end_current(); radio._process(1)
	charity.take_damage(1000)
	radio._end_current(); radio.pending.clear()
	wing.cooldown = 0
	wing.request_status()
	radio._process(1)
	drain_current()
	check(radio.current_id.ends_with("no_response") and not radio.caption.visible and radio.start_delay > 0, "Both lost: no response waits a short pause")
	radio._process(2)
	check(radio.caption.text.contains("No response") and radio.player.stream == null, "Both lost: brief silent indication, no repeated loss speech")
	var old_radio_id: int = radio.get_instance_id()
	var old_wing: WingmanRadio = wing
	session.restart_malta()
	await frames(180)
	check(not is_instance_valid(old_wing) and session.harbour.wingman_radio.request_number == 0 and mixer.radio_owner != old_radio_id, "Retry clears old requests, cooldown/channel and perception")
	check(session.harbour.definition.faith_status_voice != null and session.harbour.definition.hope_status_ack != null and session.harbour.definition.charity_status_ack != null, "Retry restores all three stable voice assignments")
	# Missing clips still give truthful reports.
	wing = session.harbour.wingman_radio
	radio = session.harbour.radio
	var definition: HarbourDefinition = session.harbour.definition.duplicate()
	definition.faith_status_voice = null
	definition.hope_status_ack = null
	definition.charity_status_ack = null
	session.harbour.definition = definition
	radio.definition = definition
	radio._end_current(); radio.pending.clear(); radio.set_process(false)
	wing.request_status(); radio._process(1)
	check(radio.caption.visible and radio.player.stream == null and radio.caption.text.contains("FAITH:"), "Missing recording falls back to labelled subtitle without blocking")
	session.show_selection()
	await frames(5)
	check(session.harbour == null and mixer.radio_owner == 0, "Leaving stops radio and frees spotting state")
	print("WINGMAN RADIO RESULT: ",checks-failures,"/",checks," passed")
	mixer.playback_enabled = false
	mixer.set_menu_active(false)
	mixer.music.stop()
	mixer.music.stream = null
	report.clear()
	threat.clear()
	definition = null
	session.queue_free()
	await frames(5)
	OS.delay_msec(200)
	quit(1 if failures else 0)
