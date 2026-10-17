extends "res://tests/malta_journey_checks.gd"
## No pose/velocity fixtures: normal interaction, taxi and takeoff from dispersal.
func _run() -> void:
	session = preload("res://main.tscn").instantiate()
	root.add_child(session)
	session.start_harbour()
	await _frames(180)
	mission = session.malta_mission
	_check(mission.board_nearest(), "Board Faith from Hal Far dispersal")
	player = mission.occupied
	var engine_key := InputEventKey.new()
	engine_key.physical_keycode = KEY_I
	engine_key.pressed = true
	Input.parse_input_event(engine_key)
	await _frames(3)
	_check(player.engine_running, "Normal I input starts Faith's engine")
	engine_key.pressed = false
	Input.parse_input_event(engine_key)
	player.pilot.automated = true
	var field: MaltaAirfield = session.field.fields.hal_far
	_check(session.harbour.wingmen.all(func(f):return field.to_local(f.global_position).z > field.runway_length*.38), "Wingmen wait behind departure taxi/takeoff lane")
	_check(await _taxi(field.to_global(Vector3(0,1.18,field.runway_length*.31-30)),7,10000), "Taxi onto Hal Far runway without hitting waiting wingmen")
	_check(await _taxi(field.to_global(Vector3(0,1.18,220)),5,16000), "Straighten on runway through normal wheel physics")
	_check(session.harbour.wave == 0 and session.encounters.active.is_empty(), "Ground engine/taxi time does not start waves")
	for tick in 9000:
		player.pilot.rudder = clampf(_heading_error(field.to_global(Vector3(0,1.18,-1600))) * .8,-.5,.5)
		player.pilot.throttle = 1
		player.pilot.brakes = false
		var pitch: float = asin(clampf((-player.global_basis.z).y,-1,1))
		player.pilot.pitch = clampf((.12-pitch)*4,-.5,.5) if player.airspeed > 31 else 0
		player.pilot.roll = clampf(-player.global_basis.x.y * 3,-.5,.5)
		await physics_frame
		if session.harbour.wave == 1 or player.is_crashed: break
	_check(not player.is_crashed and not player.is_destroyed and player.altitude >= 65, "Faith takes off and climbs with unchanged Sea Gladiator physics")
	_check(session.harbour.wave == 1 and session.harbour.wave_spawn_counts == [4], "Sustained airborne flight activates one formation after real takeoff")
	_check(session.harbour.wingmen.all(func(f):return not f.ai.takeoff_hold), "Takeoff releases wingmen, no dependence on their takeoff success")
	print("HARBOUR DEPARTURE RESULT: ",checks-failures,"/",checks," passed")
	_finish()
