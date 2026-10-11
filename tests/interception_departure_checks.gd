extends "res://tests/malta_journey_checks.gd"
## Reuse the existing test pilot's ordinary taxi/flight commands. No pose fixture,
## teleport, or velocity assignment anywhere between Ta' Qali and the checkpoint.
func _run() -> void:
	session = preload("res://main.tscn").instantiate()
	root.add_child(session)
	session.start_interception("spitfire")
	await _frames(180)
	mission = session.malta_mission
	_check(mission.board_nearest(), "Board at geographic Ta' Qali without a fixture")
	player = mission.occupied
	var world_id: int = mission.world.get_instance_id()
	var engine_key: InputEventKey = InputEventKey.new()
	engine_key.physical_keycode = KEY_I
	engine_key.pressed = true
	Input.parse_input_event(engine_key)
	await _frames(3)
	_check(player.engine_running, "Normal I key starts mission engine")
	engine_key.pressed = false
	Input.parse_input_event(engine_key)
	player.pilot.automated = true
	var field: MaltaAirfield = mission.world.fields.ta_qali
	_check(await _taxi(field.to_global(Vector3(0, 1.18, field.runway_length * 0.31 - 30)), 7, 10000), "Taxi from parking to Ta' Qali runway with wheel physics")
	_check(await _taxi(field.to_global(Vector3(0, 1.18, 220)), 5, 16000), "Straighten on Ta' Qali runway")
	_check(session.encounters.active.is_empty() and session.interception.elapsed == 0, "Taxi/engine time does not start formation or timer")
	for tick in range(5000):
		player.pilot.rudder = clampf(_heading_error(field.to_global(Vector3(0, 1.18, -1300))) * 2, -1, 1)
		player.pilot.throttle = 1
		var pitch: float = asin(clampf((-player.global_basis.z).y, -1, 1))
		player.pilot.pitch = clampf((0.10 - pitch) * 3, -0.5, 0.5) if player.airspeed > 44 else 0
		await physics_frame
		if player.altitude > 60 or player.is_crashed:
			break
	_check(not player.is_crashed and player.altitude > 60, "Take off through the unchanged aerodynamic controller")
	if not player.is_crashed:
		steering = EnemyPilot.new()
		steering.aircraft = player
		steering.measured_terrain = true
		steering.minimum_agl = 65
		steering.cruise_speed = 70
		_check(await _fly(session.interception.definition.checkpoint, 200, 26000), "Physically climb/turn from Ta' Qali to airborne checkpoint")
		await _frames(3)
		_check(session.interception.activated and session.encounters.active.size() == 2, "Real departure flight activates exactly the mission formation")
		_check(session.interception.elapsed > 0 and session.interception.elapsed < 15, "Countdown excludes all time spent starting, taxiing and taking off")
		_check(mission.world.get_instance_id() == world_id and session.aircraft == player and not player.reset_pending, "Ground-to-checkpoint flight retains world and player with no resets")
	if steering != null:
		steering.free()
	print("INTERCEPTION DEPARTURE CHECKS: ", checks, " checks; ", failures, " failures")
	session.queue_free()
	await _frames(3)
	quit(0 if failures == 0 else 1)
