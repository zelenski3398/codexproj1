extends SceneTree
## Integration against the real imported geometry, bodies, input and shared combat.
## Pose fixtures below initialize takeoff/landing scenarios; travel and landing
## afterward use forces. Fixtures are explicitly distinct from end-to-end flight.
var world: Node3D
var mission: MaltaMission
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = preload("res://main.tscn").instantiate()
	root.add_child(world)
	await _frames(3)
	_check(world.selector != null and world.field is Airfield, "Original countryside remains the default selectable environment")
	world.selector.malta_button.pressed.emit()
	await _frames(3)
	_check(world.malta_menu != null and world.aircraft == null, "Malta map selection opens airfield chart before spawning a mission")
	_check(world.malta_menu.chart.buttons.size() == 3 and world.malta_menu.selected_field == "ta_qali", "Map exposes Ta' Qali, Luqa and Ħal Far")
	world.malta_menu.select_field("hal_far")
	_check(world.malta_menu.selected_field == "hal_far" and world.malta_menu.info.text.contains("Ħal Far"), "Airfield selection updates name, available aircraft and departure")
	world.malta_menu.select_field("ta_qali")
	world.malta_menu.depart_button.pressed.emit()
	await _frames(180)
	mission = world.malta_mission
	_check(world.field is MaltaWorld and mission.world.mesh_count == 36, "All 36 supplied island meshes occupy one continuous metre-scale world")
	_check(mission.world.fields.size() == 3 and mission.fleet.size() == 6, "All three airfields and six configurable stationed aircraft coexist")
	_check(mission.world.bounds.size.x > 35000 and mission.world.bounds.size.z > 32000, "Terrain bounds retain 1:1 geographical proportions")
	_check(mission.pilot.active and mission.occupied == null and mission.pilot.is_on_floor(), "Mission starts with a collision-driven pilot beside the selected aircraft")
	for aircraft in mission.fleet:
		print("Parking ",aircraft.name," speed=",aircraft.airspeed," gear=",aircraft.gear.contact_count," altitude=",aircraft.altitude," crash=",aircraft.is_crashed)
		_check(not aircraft.is_crashed and aircraft.gear.contact_count == 3 and aircraft.airspeed < 0.3, "Parked " + aircraft.name + " rests stably on the graded field")
	_key(KEY_ESCAPE)
	for frame in range(4):
		await process_frame
	_check(paused, "Escape pauses the mission while walking")
	var parked_point: Vector3 = mission.initial_aircraft.global_position
	await process_frame
	_key(KEY_ESCAPE)
	await _frames(3)
	_check(not paused and mission.initial_aircraft.global_position.distance_to(parked_point) < 0.1, "Escape resumes on foot; aircraft physics remains paused")
	_check(mission.nearest_serviceable() == mission.initial_aircraft, "Selected serviceable Spitfire is boardable at Ta' Qali")
	_key(KEY_E)
	await _frames(4)
	var player: FlightAircraft = mission.occupied
	_check(player == mission.initial_aircraft and not mission.pilot.active and world.enemy.target == player, "E boards the existing Spitfire and routes enemy target and player input")
	_check(not player.engine_running and player.pilot.throttle == 0, "Boarding leaves engine stopped and throttle at idle")
	_key(KEY_I)
	_key(KEY_W, true)
	await _frames(120)
	_key(KEY_W, false)
	print("Taxi input engine=",player.engine_running," throttle=",player.pilot.throttle," speed=",player.airspeed)
	_check(player.engine_running and player.pilot.throttle > 0.25 and player.airspeed > 0.2, "I starts the existing engine; W produces real taxi acceleration")
	_key(KEY_M)
	await _frames(3)
	_check(mission.chart_panel.visible and not paused and mission.chart.player_position.distance_to(player.global_position) < 2, "M opens a live non-pausing chart tracking aircraft position")
	_key(KEY_M)
	_check(MaltaGeography.chart_to_world(MaltaGeography.chart_uv(player.global_position), player.global_position.y).distance_to(player.global_position) < 0.01, "World/chart conversion round trips to centimetre accuracy")
	# Initialize runway takeoff using the existing reset-fixture API once.
	world.enemy.ai.combat_enabled = false
	var home: MaltaAirfield = mission.world.fields.ta_qali
	player.pilot.automated = true
	player.request_reset()
	player.pending_reset_pose = home.global_transform * Transform3D(Basis(Vector3.RIGHT, 0.117), Vector3(0, 1.18, 480))
	await _frames(6)
	player.pilot.throttle = 1
	for tick in range(3600):
		var pitch: float = asin(clampf((-player.global_basis.z).y, -1, 1))
		player.pilot.pitch = clampf((0.10 - pitch) * 3, -0.5, 0.5) if player.airspeed > 43 else 0.0
		await physics_frame
		if player.altitude > 30 or player.is_crashed:
			break
	print("Malta takeoff position=",player.global_position," speed=",player.airspeed," AGL=",player.altitude," crash=",player.crash_reason)
	_check(not player.is_crashed and player.altitude > 30 and player.gear.contact_count == 0, "Spitfire takes off from Ta' Qali under unchanged force-driven aerodynamics")
	player.components.apply_damage(&"left_wing", 10)
	player.components.fuel_remaining = 0.63
	var hp: float = player.health.hp
	var wing: float = player.components.integrity_ratio(&"left_wing")
	var scene_id: int = mission.world.get_instance_id()
	var enemy_id: int = world.enemy.get_instance_id()
	# Landing fixture at Ħal Far, then actual gravity/lift/suspension/brakes.
	var destination: MaltaAirfield = mission.world.fields.hal_far
	# Fixture assigns physics pose without request_reset: retain actual damage/fuel.
	PhysicsServer3D.body_set_state(player.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, destination.global_transform * Transform3D(Basis(Vector3.RIGHT, 0.085), Vector3(0, 3.6, 300)))
	PhysicsServer3D.body_set_state(player.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, -destination.global_basis.z * 46 + Vector3.DOWN * 0.8)
	PhysicsServer3D.body_set_state(player.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	player.pilot.throttle = 0
	var touched: bool = false
	for tick in range(3000):
		var pitch: float = asin(clampf((-player.global_basis.z).y, -1, 1))
		player.pilot.pitch = clampf((0.085 + atan(float(destination.record.slope)) - pitch) * 3, -0.4, 0.4)
		if player.gear.contact_count > 0:
			touched = true
			player.pilot.brakes = true
		await physics_frame
		if player.is_crashed or (touched and player.airspeed < 0.2):
			break
	print("Malta landing speed=",player.airspeed," touch=",touched," crash=",player.crash_reason," position=",player.global_position)
	_check(touched and not player.is_crashed and player.airspeed < 1, "Spitfire lands and brakes on Ħal Far's sloping collision surface")
	player.engine_running = false
	player.pilot.throttle = 0
	_check(mission.leave_aircraft(), "Pilot can leave the stopped aircraft at a different airfield")
	_check(player.health.hp == hp and player.components.integrity_ratio(&"left_wing") == wing and player.components.fuel_remaining <= 0.63, "Leaving preserves aircraft health, component damage and fuel")
	# Walk-position fixture verifies local boarding at the other field; no reset.
	var replacement: FlightAircraft = mission.fleet[5]
	mission.pilot.global_position = replacement.global_position + replacement.global_basis.x * 6
	await _frames(5)
	_check(mission.board_nearest() and mission.occupied == replacement and replacement is SeaGladiator, "A serviceable stationed Sea Gladiator can be boarded at Ħal Far")
	_check(mission.world.get_instance_id() == scene_id and world.enemy.get_instance_id() == enemy_id and mission.fleet.size() == 6, "Changing aircraft keeps the same world, fleet and enemy without reloading")
	_check(player.health.hp == hp and not player.engine_running and player.pilot.automated and player.pilot.brakes, "Previous Spitfire stays parked with damage and engine state")
	var installation: AirfieldInstallation = destination.installations[0]
	installation.take_damage(installation.max_hp)
	_check(installation.is_destroyed and installation.hp == 0, "Ground installation damage and ruins persist in the world")
	world.enemy.take_damage(100)
	await _frames(2)
	var notifications: int = world.defeat_notifications
	mission.occupied = null
	_check(world.enemy.is_destroyed and world.enemy_defeated and notifications == 1, "Enemy destruction is one-shot and does not respawn on aircraft changes")
	world.restart_malta()
	await _frames(120)
	_check(world.malta_mission.fleet.size() == 6 and world.enemy.health.hp == 100 and not world.enemy_defeated and world.malta_mission.occupied == null, "Explicit full restart creates one fresh enemy, clean fleet and pilot")
	_check(world.malta_mission.world.get_instance_id() != scene_id and world.malta_mission.fleet[0].health.hp == 100, "Only explicit mission restart replaces the environment and damaged aircraft")
	world.show_selection()
	await _frames(3)
	_check(world.environment_id == "countryside" and world.field is Airfield and world.malta_mission == null, "End mission returns to preserved countryside and aircraft selection")
	world.start_flight("spitfire")
	await _frames(3)
	_check(not world.enemy.ai.measured_terrain and world.enemy.ai.world_extent == Airfield.EXTENT and world.enemy.ai.pursuit_release_range == 7500, "Returning to countryside restores its terrain and enemy boundary tuning")
	print("MALTA RESULT: ", checks-failures, "/", checks," passed; ",failures," failed")
	quit(1 if failures else 0)

func _frames(count: int) -> void:
	for tick in range(count):
		await physics_frame

func _key(code: Key, pressed: bool = true) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	if pressed and code not in [KEY_W]:
		event = InputEventKey.new()
		event.keycode = code
		event.pressed = false
		Input.parse_input_event(event)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
