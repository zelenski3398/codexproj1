extends SceneTree
## End-to-end route: no reset, transform/velocity assignment, scene replacement or
## teleport once the mission spawns. Test autopilot submits ordinary pilot inputs.
var session: Node3D
var player: FlightAircraft
var mission: MaltaMission
var checks: int = 0
var failures: int = 0
var steering: EnemyPilot

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	session = preload("res://main.tscn").instantiate()
	root.add_child(session)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var home: String = args[0] if not args.is_empty() else "ta_qali"
	session.start_malta(home, "spitfire")
	await _frames(150)
	mission = session.malta_mission
	_check(mission.board_nearest(), "Spawn beside and enter the selected " + home + " Spitfire")
	player = mission.occupied
	var engine_key: InputEventKey = InputEventKey.new()
	engine_key.physical_keycode = KEY_I
	engine_key.pressed = true
	Input.parse_input_event(engine_key)
	await _frames(3)
	_check(player.engine_running, "Start the boarded Spitfire through normal engine input")
	engine_key.pressed = false
	Input.parse_input_event(engine_key)
	player.pilot.automated = true
	session.enemy.ai.combat_enabled = false # isolate route safety from combat luck
	var field: MaltaAirfield = mission.world.fields[home]
	var world_id: int = mission.world.get_instance_id()
	var started: Vector3 = player.global_position
	var taxi: bool = await _taxi(field.to_global(Vector3(0, 1.18, field.runway_length * 0.31 - 30)), 7, 10000)
	_check(taxi and not player.is_crashed, "Taxi from dispersal onto " + String(field.record.name) + " runway with normal steering and thrust")
	_check(await _taxi(field.to_global(Vector3(0, 1.18, 220)), 5, 16000), "Straighten on the runway before applying takeoff power")
	# Follow the runway; straightening happens through rudder torque during roll.
	for tick in range(5000):
		var goal: Vector3 = field.to_global(Vector3(0, 1.18, -field.runway_length * 0.5 - 500))
		var error: float = _heading_error(goal)
		player.pilot.rudder = clampf(error * 2, -1, 1)
		player.pilot.throttle = 1
		var pitch: float = asin(clampf((-player.global_basis.z).y, -1, 1))
		player.pilot.pitch = clampf((0.10 - pitch) * 3, -0.5, 0.5) if player.airspeed > 44 else 0.0
		await physics_frame
		if player.altitude > 60 or player.is_crashed:
			break
	print("Journey takeoff: position=",player.global_position," AGL=",player.altitude," speed=",player.airspeed," crash=",player.crash_reason)
	_check(not player.is_crashed and player.altitude > 60, "Take off from parked Spitfire without any pose fixture")
	if player.is_crashed:
		_finish()
		return
	steering = EnemyPilot.new()
	steering.aircraft = player
	steering.measured_terrain = true
	steering.minimum_agl = 35
	steering.cruise_speed = 70
	steering.mode = "PATROL"
	if home == "luqa":
		var ta_qali: Vector3 = MaltaGeography.vector(MaltaGeography.field("ta_qali").position)
		ta_qali.y += 600
		_check(await _fly(ta_qali, 700, 26000), "Fly from Luqa toward Ta' Qali using ordinary aerodynamic controls")
	var valletta: Vector3 = MaltaGeography.vector(MaltaGeography.data().landmarks[0].position)
	valletta.y = 600
	_check(await _fly(valletta, 600, 25000), "Fly continuously over Valletta with physical pitch, bank and rudder controls")
	var harbour: Vector3 = MaltaGeography.vector(MaltaGeography.data().landmarks[1].position)
	harbour.y = 600
	_check(await _fly(harbour, 650, 10000), "Continue to Grand Harbour in the same world")
	var destination: MaltaAirfield = mission.world.fields.hal_far
	var outer: Vector3 = destination.to_global(Vector3(0, 300, 4000))
	_check(await _fly(outer, 700, 30000), "Fly south to the Ħal Far approach without loading or resetting")
	# Wide circuit to align with the strip at a safe height before descent.
	var inner: Vector3 = destination.to_global(Vector3(0, 120, 2500))
	steering.cruise_speed = 46
	_check(await _fly(inner, 100, 16000), "Align and descend on Ħal Far approach under physics")
	_check(await _fly(destination.to_global(Vector3(0, 35, 1800)), 25, 10000), "Establish low-speed final approach before flare")
	var touched: bool = false
	var next_report: float = 1800
	for tick in range(16000):
		var local: Vector3 = destination.to_local(player.global_position)
		if local.z < next_report:
			print("Final approach local=",local," speed=",player.airspeed," sink=",player.linear_velocity.y)
			next_report -= 300
		var height: float = clampf((local.z - destination.runway_length * 0.44) * 0.04 + 1.6, 1.6, 220)
		var aim: Vector3 = destination.to_global(Vector3(0, height, local.z - 350))
		steering.cruise_speed = 46
		steering.minimum_agl = 0
		steering._fly_toward(aim, 1.0 / 120)
		# Follow a 4% glideslope using measured vertical velocity and ordinary
		# pitch/throttle, then flare only near the strip surface, never early.
		var pitch: float = asin(clampf((-player.global_basis.z).y, -1, 1))
		var target_height: float = maxf((local.z - destination.runway_length * 0.43) * 0.04 + 1.3, 1.3)
		var desired_sink: float = clampf((target_height - local.y) * 0.18, -3, 1) + float(destination.record.slope) * maxf((-destination.global_basis.z).dot(player.linear_velocity), 0)
		var desired_pitch: float = 0.045 + (desired_sink - player.linear_velocity.y) * 0.025
		player.pilot.pitch = clampf((desired_pitch - pitch) * 4, -0.4, 0.4)
		player.pilot.throttle = clampf(0.10 + (46 - player.airspeed) * 0.04, 0, 0.35)
		if local.y < 6 and local.z < destination.runway_length * 0.5:
			player.pilot.pitch = clampf((0.085 + atan(float(destination.record.slope)) - pitch) * 3, -0.4, 0.4)
			player.pilot.throttle = 0
		if player.gear.contact_count > 0:
			touched = true
			player.pilot.throttle = 0
			player.pilot.brakes = true
		await physics_frame
		if player.is_crashed or (touched and player.airspeed < 0.2):
			break
	print("Journey landing: local=",destination.to_local(player.global_position)," speed=",player.airspeed," crash=",player.crash_reason)
	_check(touched and not player.is_crashed and player.airspeed < 1 and destination.contains(player.global_position), "Land and stop at Ħal Far in uninterrupted flight")
	if player.is_crashed:
		_finish()
		return
	# Taxi the landed aircraft near the other parked aeroplane, then walk to it.
	var parked: FlightAircraft = mission.fleet[5]
	player.pilot.brakes = false
	player.pilot.pitch = 0
	var dispersal: Vector3 = destination.to_global(Vector3(40, 1.18, destination.runway_length * 0.31 - 35))
	_check(await _taxi(destination.to_global(Vector3(0, 1.18, destination.runway_length * 0.31 - 35)), 6, 60000), "Follow the runway to the apron connection")
	_check(await _taxi(dispersal, 9, 16000), "Taxi to Ħal Far dispersal using wheel steering")
	player.pilot.throttle = 0
	player.pilot.brakes = true
	await _frames(600)
	player.engine_running = false
	_check(mission.leave_aircraft(), "Exit the landed Spitfire without resetting the mission")
	# Walk around the stopped aircraft first, using collision, not a position fixture.
	await _walk_to(mission.pilot.global_position - player.global_basis.z * 12, 3, 1600)
	# Walk through real CharacterBody collision, with the normal movement axes.
	for tick in range(5000):
		var offset: Vector3 = parked.global_position - mission.pilot.global_position
		if offset.length() < 7.5:
			break
		mission.pilot.yaw = atan2(-offset.x, -offset.z)
		Input.action_press("throttle_up")
		await physics_frame
	Input.action_release("throttle_up")
	_check(mission.board_nearest() and mission.occupied == parked, "Walk to and board the stationed Sea Gladiator")
	# Luqa is closer to Hal Far than Ta' Qali; compare the actual departure/destination.
	var departure_span: float = field.global_position.distance_to(destination.global_position)
	_check(mission.world.get_instance_id() == world_id and player.global_position.distance_to(started) > departure_span * 0.75, "Entire journey keeps the identical terrain/world instance")
	if mission.occupied == parked:
		player = parked
		player.engine_running = true
		player.pilot.automated = true
		_check(await _taxi(destination.to_global(Vector3(0, 1.18, destination.runway_length * 0.31 - 65)), 7, 15000), "Taxi the second aircraft onto the departure strip")
		_check(await _taxi(destination.to_global(Vector3(0, 1.18, 120)), 5, 14000), "Straighten the replacement aircraft before takeoff")
		for tick in range(6000):
			player.pilot.throttle = 1
			player.pilot.rudder = clampf(_heading_error(destination.to_global(Vector3(0, 1.18, -1300))) * 2, -1, 1)
			var pitch: float = asin(clampf((-player.global_basis.z).y, -1, 1))
			player.pilot.pitch = clampf((0.10 - pitch) * 3, -0.5, 0.5) if player.airspeed > 31 else 0.0
			await physics_frame
			if player.is_crashed or player.altitude > 25:
				break
		_check(not player.is_crashed and player.altitude > 25, "Take off again in the Sea Gladiator without reloading Malta")
	_finish()

func _heading_error(goal: Vector3) -> float:
	var direction: Vector3 = goal - player.global_position
	var forward: Vector3 = -player.global_basis.z
	return wrapf(atan2(-direction.x, -direction.z) - atan2(-forward.x, -forward.z), -PI, PI)

func _taxi(goal: Vector3, radius: float, ticks: int) -> bool:
	var aligning: bool = true
	player.pilot.pitch = 0
	player.pilot.roll = 0
	player.pilot.brakes = false
	for tick in range(ticks):
		var offset: Vector3 = goal - player.global_position
		offset.y = 0
		if offset.length() < radius:
			player.pilot.throttle = 0
			return true
		var heading_error: float = _heading_error(goal)
		if absf(heading_error) > 1:
			aligning = true
		if aligning:
			player.pilot.throttle = 0
			player.pilot.brakes = true
			player.pilot.rudder = signf(heading_error)
			if absf(heading_error) < 0.12:
				aligning = false
			await physics_frame
			continue
		player.pilot.rudder = clampf(heading_error * 2.2, -1, 1)
		player.pilot.throttle = clampf(0.10 + (4 - player.airspeed) * 0.10, 0, 0.35)
		player.pilot.brakes = player.airspeed > 5
		await physics_frame
		if player.is_crashed:
			print("Taxi crash ",player.global_position," goal=",goal," reason=",player.crash_reason)
			return false
	print("Taxi timeout ",player.global_position," goal=",goal," error=",_heading_error(goal))
	return false

func _fly(goal: Vector3, radius: float, ticks: int) -> bool:
	for tick in range(ticks):
		steering._fly_toward(goal, 1.0 / 120)
		await physics_frame
		if player.is_crashed:
			return false
		if player.global_position.distance_to(goal) < radius:
			return true
	print("Flight timeout position=",player.global_position," target=",goal," altitude=",player.altitude)
	return false

func _walk_to(goal: Vector3, radius: float, ticks: int) -> bool:
	for tick in range(ticks):
		var offset: Vector3 = goal - mission.pilot.global_position
		offset.y = 0
		if offset.length() < radius:
			Input.action_release("throttle_up")
			return true
		mission.pilot.yaw = atan2(-offset.x, -offset.z)
		Input.action_press("throttle_up")
		await physics_frame
	Input.action_release("throttle_up")
	return false

func _frames(count: int) -> void:
	for tick in range(count):
		await physics_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ",description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _finish() -> void:
	if steering != null:
		steering.free()
	print("MALTA JOURNEY RESULT: ",checks-failures,"/",checks," passed; ",failures," failed")
	quit(1 if failures else 0)
