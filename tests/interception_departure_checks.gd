extends "res://tests/malta_journey_checks.gd"
## Reuse the existing test pilot's ordinary taxi/flight commands. No pose fixture,
## teleport, or velocity assignment anywhere between Ta' Qali and the checkpoint.
var airborne_clock: float = 0
var airborne_path: float = 0
var contact_time: float = 0
var contact_path: float = 0
func _run() -> void:
	session = preload("res://main.tscn").instantiate()
	root.add_child(session)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var kind: String = args[0] if not args.is_empty() else "spitfire"
	session.start_interception(kind)
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
		var previous: Vector3 = player.global_position
		player.pilot.rudder = clampf(_heading_error(field.to_global(Vector3(0, 1.18, -1300))) * 2, -1, 1)
		player.pilot.throttle = 1
		var pitch: float = asin(clampf((-player.global_basis.z).y, -1, 1))
		player.pilot.pitch = clampf((0.10 - pitch) * 3, -0.5, 0.5) if player.airspeed > 44 else 0
		await physics_frame
		if player.gear.contact_count == 0 and player.altitude > 5:
			airborne_clock += 1.0 / 120
			airborne_path += previous.distance_to(player.global_position)
		elif player.gear.contact_count > 0:
			airborne_clock = 0 # ignore a transient runway bounce
			airborne_path = 0
		if player.altitude > 60 or player.is_crashed:
			break
	_check(not player.is_crashed and player.altitude > 60, "Take off through the unchanged aerodynamic controller")
	session.interception.formation_detected.connect(func(_distance: float):
		contact_time = airborne_clock
		contact_path = airborne_path
		for foe in session.encounters.active:
			foe.ai.combat_enabled = false) # isolate route timing from dogfight luck
	if not player.is_crashed:
		steering = EnemyPilot.new()
		steering.aircraft = player
		steering.measured_terrain = true
		steering.minimum_agl = 65
		steering.cruise_speed = 55 if kind == "sea_gladiator" else 70
		for index in range(session.interception.definition.checkpoint_positions.size()):
			var goal: Vector3 = session.interception.definition.checkpoint_positions[index]
			_check(await _fly(goal, 200, 12000), "Physically fly checkpoint %d with ordinary aerodynamic controls" % (index + 1))
			await _frames(3)
			_check(session.interception.checkpoint_index == index + 1, "Normal flight captures checkpoint %d in order" % (index + 1))
			if index < session.interception.definition.checkpoint_positions.size() - 1:
				_check(session.interception.elapsed == 0 and session.encounters.active.is_empty(), "Navigation flight leaves timer/enemies inactive")
		print("DEPARTURE ACTIVATION_DISTANCE_METRES=", session.interception.activation_distance, " BOMBER_ROUTE_METRES=", session.interception.bomber_route_length)
		print("LIFTOFF_TO_CONTACT_SECONDS=", contact_time, " AIRBORNE_PATH_METRES=", contact_path, " FORMATION_HEIGHT_DIFFERENCE=", session.interception.bomber.global_position.y - player.global_position.y)
		_check(contact_time < 120 and contact_path < 6000, "Short actual flight reaches contact within two minutes and six kilometres of liftoff")
		_check(absf(session.interception.activation_bearing - 30) < 0.001 and absf(session.interception.bomber.global_position.y - player.global_position.y) < 150, "Real departure yields a practical one-o'clock formation altitude")
		_check(absf(session.interception.activation_distance - 1200) < 1, "Uninterrupted departure starts 1200 metres from the bomber")
		await _frames(3)
		_check(session.interception.activated and session.encounters.active.size() == 2, "Real departure flight activates exactly the mission formation")
		_check(session.interception.elapsed > 0 and session.interception.elapsed < 15, "Countdown excludes all time spent starting, taxiing and taking off")
		_check(mission.world.get_instance_id() == world_id and session.aircraft == player and not player.reset_pending, "Ground-to-checkpoint flight retains world and player with no resets")
		# Isolate uninterrupted bomber timing from dogfight luck; the player
		# continues flying normally offshore, never reset/frozen/teleported.
		for foe in session.encounters.active:
			foe.ai.combat_enabled = false
		var heading: Vector3 = session.interception.activation_approach
		for tick in range(12000):
			var goal: Vector3 = player.global_position + heading * 2000
			goal.y = 500
			steering._fly_toward(goal, 1.0 / 120)
			await physics_frame
			if (session.interception.bomber.ai as BomberPilot).arrived and session.interception.phase != "ACTIVE":
				break
		var arrival: float = (session.interception.bomber.ai as BomberPilot).arrival_elapsed
		print("DEPARTURE BOMBER_TRAVEL_SECONDS=", arrival)
		_check(arrival >= 88 and arrival <= 92, "Bomber from the actual departure capture reaches Valletta in approximately 90 seconds")
		_check(not player.is_destroyed and not player.is_crashed and session.interception.final_reason == "Valletta bombed — interception failed", "Continuous player flight and actual bomber-arrival failure remain intact")
	if steering != null:
		steering.free()
	print("INTERCEPTION DEPARTURE CHECKS: ", checks, " checks; ", failures, " failures")
	session.queue_free()
	await _frames(3)
	quit(0 if failures == 0 else 1)

func _fly(goal: Vector3, radius: float, ticks: int) -> bool:
	for tick in range(ticks):
		var previous: Vector3 = player.global_position
		steering._fly_toward(goal, 1.0 / 120)
		await physics_frame
		airborne_clock += 1.0 / 120
		airborne_path += previous.distance_to(player.global_position)
		if player.is_crashed:
			return false
		if player.global_position.distance_to(goal) < radius:
			return true
	return false
