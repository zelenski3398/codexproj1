extends SceneTree
## Real flight/combat with explicit fixture resets for checkpoint/outcome branches.
## The uninterrupted approach below uses only normal pilot commands for 300 s.
var session: Node3D
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	session = preload("res://main.tscn").instantiate()
	root.add_child(session)
	await _frames(3)
	_check(session.selector.missions_button != null, "Main menu offers Missions without replacing original choices")
	session.show_missions()
	_check(session.missions_menu != null and session.selector == null, "Missions entry opens briefing")
	session.missions_menu.launch_button.pressed.emit()
	await _frames(180)
	var mission: VallettaInterception = session.interception
	_check(session.game_mode == "interception" and session.malta_mission.home == "ta_qali", "Mission departs from geographic Ta' Qali")
	_check(session.malta_mission.occupied == null and not session.aircraft.engine_running and session.aircraft.gear.contact_count > 0, "Player starts on foot beside a grounded aircraft with engine off")
	_check(session.encounters.active.is_empty() and mission.elapsed == 0 and not mission.activated, "No enemy or timer before checkpoint")
	_check(session.malta_mission.board_nearest(), "Manual boarding remains available")
	var player: FlightAircraft = session.aircraft
	var world_id: int = session.field.get_instance_id()
	var impacts: Array[Vector3] = []
	var activation_state: Dictionary = {}
	mission.checkpoint_reached.connect(func(number: int):
		if number == mission.definition.checkpoint_positions.size():
			# Disclosed damaged-aircraft fixture immediately before the transition.
			player.take_damage(20)
			player.components.fuel_remaining = 0.53
			player.components.integrity[&"engine"] = 57
			player.engine_running = false
			player.pilot.throttle = 0.37
			player.guns.pool.spawn(player.global_position + Vector3.UP * 1000, Vector3.FORWARD * 10, 60, 1, player.get_rid(), false, player.team_id)
			activation_state.before = _player_snapshot(player)
	)
	mission.formation_detected.connect(func(_distance: float): activation_state.after = _player_snapshot(player))
	# Pose fixtures visit the REAL ordered capture logic, including out-of-order
	# entries and dwelling/re-entering a completed checkpoint.
	mission.activate()
	_check(not mission.activated, "Direct activation cannot skip navigation checkpoints")
	await _checkpoint_pose(player, mission.definition.checkpoint_positions[-1], Vector3.FORWARD)
	_check(mission.checkpoint_index == 0 and not mission.activated and mission.elapsed == 0, "Final checkpoint visited early cannot skip the sequence")
	var positions: PackedVector3Array = mission.definition.checkpoint_positions
	for point in positions:
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2000, point + Vector3.DOWN * 3000, 1)
		var ground: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(ray)
		_check(not ground.is_empty() and point.y - float(ground.position.y) >= mission.definition.minimum_checkpoint_agl, "Configured navigation checkpoint is above measured terrain/sea")
	for index in range(positions.size()):
		var previous: Vector3 = positions[index - 1] if index > 0 else MaltaGeography.vector(MaltaGeography.field("ta_qali").position)
		var approach: Vector3 = ((positions[index] - previous) * Vector3(1, 0, 1)).normalized()
		await _checkpoint_pose(player, positions[index], approach)
		_check(mission.checkpoint_index == index + 1, "Checkpoint %d advances once in order" % (index + 1))
		if index < positions.size() - 1:
			_check(mission.elapsed == 0 and not mission.countdown_started and session.encounters.active.is_empty(), "Checkpoint %d leaves countdown stopped and enemies absent" % (index + 1))
			mission._advance_checkpoint(index) # stale duplicate callback for this entry
			await _frames(3)
			_check(mission.checkpoint_index == index + 1, "Dwelling/stale entry cannot count checkpoint %d twice" % (index + 1))
	_check(activation_state.before == activation_state.after, "Activation preserves exact player transform, velocity, HP, engine, throttle, fuel, component and weapon state")
	_check(mission.objective.text.contains(MissionRadio.FORMATION_LINE), "Activation shows the formation detection message")
	_check(absf(mission.activation_distance - 2500) < 1, "Actual activation separation is 2500 metres in the existing world scale")
	var offset: Vector3 = ((mission.bomber.global_position - player.global_position) * Vector3(1, 0, 1)).normalized()
	var bearing: float = rad_to_deg(atan2(offset.dot(mission.activation_approach.cross(Vector3.UP)), offset.dot(mission.activation_approach)))
	_check(absf(bearing - 30) < 0.1, "Formation appears one o'clock, 30 degrees right of player's heading")
	_check((-mission.bomber.global_basis.z).dot((mission.definition.bombing_point - mission.bomber.global_position).normalized()) > 0.99, "Bomber initially faces Valletta while player closes head-on")
	_check(mission.bomber.global_position.distance_to(mission.escort.global_position) > 200 and mission.bomber.altitude > 300 and mission.escort.altitude > 300, "Formation has safe mutual and terrain clearance")
	print("ACTIVATION_DISTANCE_METRES=", mission.activation_distance, " BOMBER_ROUTE_METRES=", mission.bomber_route_length)
	_check(mission.activated and session.encounters.active.size() == 2, "Entering airborne checkpoint creates exactly two aircraft")
	_check(mission.bomber.aircraft_kind == "sm79" and mission.escort.aircraft_kind == "c200", "Formation contains the specified bomber and escort")
	_check(mission.elapsed > 0 and mission.elapsed < 0.2 and not mission.checkpoint_mesh.visible, "Countdown starts only at activation and checkpoint disappears")
	_check(not mission.bomber.gear.extended and not mission.escort.gear.extended, "Bomber and C200 spawn with their retractable undercarriage raised")
	var first_bomber: EnemyAircraft = mission.bomber
	var first_escort: EnemyAircraft = mission.escort
	for i in range(5):
		mission.activate()
	_check(mission.bomber == first_bomber and mission.escort == first_escort and session.encounters.active.size() == 2, "Repeated checkpoint entries cannot duplicate/reset formation")
	_check(session.field.get_instance_id() == world_id and session.aircraft == player, "Checkpoint transition preserves world and aircraft")
	# Keep the player safely grounded; bomber and escort must still navigate.
	player.request_reset()
	player.pending_reset_pose = session.malta_mission.world.fields.ta_qali.parking[0]
	player.pending_reset_velocity = Vector3.ZERO
	await _frames(5)
	player.pilot.automated = true
	player.pilot.brakes = true
	var minimum_altitude: float = INF
	var maximum_bank: float = 0
	var last_distance: float = INF
	for tick in range(40500):
		await physics_frame
		if not is_instance_valid(mission.bomber):
			break
		minimum_altitude = minf(minimum_altitude, mission.bomber.altitude)
		maximum_bank = maxf(maximum_bank, absf(mission.bomber.rotation.z))
		if tick % 6000 == 0:
			last_distance = mission.bomber.global_position.distance_to(mission.definition.bombing_point)
			print("Approach t=", mission.elapsed, " distance=", last_distance, " speed=", mission.bomber.airspeed, " altitude=", mission.bomber.global_position.y, " escort=", mission.escort.global_position.distance_to(mission.bomber.global_position), " phase=", mission.phase)
		for effect in mission.effects.get_children():
			if effect is MissionBomb and not effect.impacted.is_connected(_record_impact.bind(impacts)):
				effect.impacted.connect(_record_impact.bind(impacts))
		if mission.bombing and mission.bomb_impacts == mission.definition.bomb_count and (mission.bomber.ai as BomberPilot).route_elapsed >= mission.definition.deadline_seconds + 35:
			break
	var route: BomberPilot = mission.bomber.ai
	print("ARRIVAL_SECONDS=", route.arrival_elapsed, " minAGL=", minimum_altitude, " bank=", maximum_bank, " reason=", mission.final_reason, " released=", mission.bombs_released, " impacts=", mission.bomb_impacts)
	_check(not mission.bomber.is_destroyed and minimum_altitude > 300, "Bomber survives continuous real-force approach above Malta terrain")
	_check(route.arrived and route.arrival_elapsed >= 295 and route.arrival_elapsed <= 302, "Uninterrupted physical bomber reaches Valletta in approximately 300 seconds")
	_check(mission.phase == "FAILED" and mission.final_reason == "Valletta bombed — interception failed" and mission.result_count == 1, "Actual bomber arrival reports bombing failure once")
	_check(mission.bombs_released == mission.definition.bomb_count and mission.bomb_impacts >= 2, "Level run releases a sequence of physical falling bombs with swept ground impacts")
	_check(session.field.get_instance_id() == world_id, "Arrival/bombing never reloads continuous Malta")
	_check(route.tactic == "POST-RUN ORBIT" and not mission.bomber.is_destroyed and mission.bomber.airspeed > 45 and mission.bomber.global_position.distance_to(mission.definition.bombing_point) < 3000 and absf(mission.bomber.global_basis.x.y) > 0.02, "After level bombing the bomber turns physically into a bounded mission orbit")
	_check(not impacts.is_empty() and (impacts[0] * Vector3(1, 0, 1)).distance_to(mission.definition.target_area * Vector3(1, 0, 1)) < 250, "Ballistic release lead places the first real bomb impact in the Valletta target area")
	# Outcome branches use actual health destruction events, not smoke or flags.
	await _restart_activate()
	mission = session.interception
	mission.bomber.take_damage(51)
	_check(not mission.bomber_destroyed and mission.phase == "ACTIVE", "Smoke/low hull HP cannot clear bomber objective")
	mission.bomber.take_damage(100)
	await _frames(2)
	_check(mission.bomber_destroyed and not mission.escort_destroyed and mission.phase == "ACTIVE" and mission.objective.text.contains("Bomber stopped"), "Bomber first leaves escort objective and original countdown running")
	var defense_center: Vector3 = (mission.escort.ai as EscortPilot).last_formation_position
	await _frames(30)
	_check((mission.escort.ai as EscortPilot).last_formation_position == defense_center, "Surviving escort defends the last formation area rather than chasing a departing imaginary bomber")
	var saved_clock: float = mission.elapsed
	mission.escort.take_damage(100)
	mission.escort.take_damage(100)
	await _frames(2)
	_check(mission.success and mission.result_count == 1 and mission.elapsed >= saved_clock, "Destroying both before deadline succeeds once")
	_check(not session.encounters.awaiting_confirmation and session.encounters.active.is_empty(), "Mission kills never open the continuous encounter confirmation")
	await _restart_activate()
	mission = session.interception
	mission.escort.take_damage(100)
	await _frames(2)
	_check(not mission.bomber_destroyed and mission.phase == "ACTIVE", "Escort destruction cannot stop bomber")
	mission.bomber.take_damage(100)
	await _frames(2)
	_check(mission.success, "Escort-first destruction can also complete mission")
	await _restart_activate()
	mission = session.interception
	mission.bomber.take_damage(100)
	mission.elapsed = mission.definition.deadline_seconds
	mission._resolve()
	_check(mission.final_reason == "Interception incomplete" and not mission.success, "Escort-only survival at expiry does not falsely report bombing")
	await _restart_activate()
	mission = session.interception
	mission.elapsed = mission.definition.deadline_seconds
	mission.bomber.take_damage(100)
	mission.escort.take_damage(100)
	await _frames(2)
	_check(not mission.success and mission.result_count == 1, "Kills at exact deadline cannot become a late success")
	await _restart_activate()
	mission = session.interception
	mission.elapsed = mission.definition.deadline_seconds
	mission._resolve()
	_check(mission.final_reason == "Time expired — interception failed", "Live bomber timeout reports failure without inventing an unreached bombing")
	await _restart_activate()
	mission = session.interception
	session.aircraft.take_damage(100)
	await _frames(2)
	_check(mission.phase == "FAILED" and mission.final_reason.contains("Player aircraft destroyed") and mission.result_count == 1, "Player destruction ends mission exactly once")
	var old_mission_id: int = mission.get_instance_id()
	var old_enemy_ids: Array[int] = [mission.bomber.get_instance_id(), mission.escort.get_instance_id()]
	session.restart_malta()
	await _frames(180)
	_check(not is_instance_id_valid(old_mission_id) and not is_instance_id_valid(old_enemy_ids[0]) and not is_instance_id_valid(old_enemy_ids[1]), "Retry frees prior mission, enemies, effects and their subscriptions")
	_check(session.interception.phase == "CHECKPOINT" and session.interception.elapsed == 0 and session.encounters.active.is_empty() and session.encounters.wrecks.is_empty() and session.interception.checkpoint_index == 0, "Retry restores checkpoint gating with no old foes/timer/wrecks")
	session.return_to_missions()
	await _frames(3)
	_check(session.missions_menu != null and session.interception == null and session.malta_mission == null, "Return to Missions cleans mission and reopens briefing")
	# Returning/retrying in the same tick as a last kill must invalidate old callbacks.
	session.start_interception("spitfire")
	await _frames(180)
	preload("res://tests/interception_fixture.gd").prepare_final_entry(session)
	await _frames(6)
	session.interception.bomber.take_damage(100)
	session.interception.escort.take_damage(100)
	session.restart_malta()
	await _frames(180)
	_check(session.interception.phase == "CHECKPOINT" and not session.encounters.ended and session.interception.result_count == 0, "Old deferred resolution cannot finish a fresh retry")
	preload("res://tests/interception_fixture.gd").prepare_final_entry(session)
	await _frames(6)
	session.interception.bomber.take_damage(100)
	session.interception.escort.take_damage(100)
	await _frames(2)
	_check(session.interception.success and session.interception.result_count == 1, "Simultaneous pre-deadline kills produce one success")
	session.return_to_missions()
	await _frames(3)
	# A late physics crash can occur after capture was queued but before its
	# deferred advancement. No fresh enemies may appear for that lost aircraft.
	session.start_interception("spitfire")
	await _frames(180)
	mission = session.interception
	mission.checkpoint_index = mission.definition.checkpoint_positions.size() - 1
	session.aircraft.is_crashed = true # explicit late-contact fixture
	mission._advance_checkpoint(mission.checkpoint_index)
	_check(mission.phase == "FAILED" and not mission.activated and mission.elapsed == 0 and session.encounters.active.is_empty(), "Late crash cancels final checkpoint capture before formation creation")
	session.return_to_missions()
	await _frames(3)
	# CR.42 escort variation uses the same mission; no count or default-mode changes.
	session.start_interception("sea_gladiator")
	await _frames(180)
	_check(session.aircraft is SeaGladiator and not session.aircraft.engine_running, "Gladiator mission keeps its ground/manual-engine start")
	session.interception.definition = session.interception.definition.duplicate()
	session.interception.definition.escort_type = "cr42"
	preload("res://tests/interception_fixture.gd").prepare_final_entry(session)
	await _frames(6)
	_check(session.interception.escort.aircraft_kind == "cr42", "Escort definition supports a future CR.42 variant")
	session.queue_free()
	await _frames(3)
	print("INTERCEPTION CHECKS: ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)

func _player_snapshot(player: FlightAircraft) -> Dictionary:
	return {"pose": player.global_transform, "velocity": player.linear_velocity, "angular": player.angular_velocity, "hp": player.health.hp, "engine": player.engine_running, "throttle": player.pilot.throttle, "fuel": player.components.fuel_remaining, "components": player.components.integrity.duplicate(), "gear": player.gear.extended, "bullets": player.guns.pool.active.duplicate(), "shots": player.guns.pool.statistics.shots, "salvos": player.guns.salvo_count, "cooldown": player.guns.cooldown}

func _checkpoint_pose(player: FlightAircraft, point: Vector3, direction: Vector3) -> void:
	player.request_reset()
	player.pending_reset_pose = Transform3D(Basis.looking_at(direction, Vector3.UP), point)
	player.pending_reset_velocity = direction * 70
	player.pilot.automated = true
	await _frames(5)

func _record_impact(point: Vector3, positions: Array[Vector3]) -> void:
	positions.append(point)

func _restart_activate() -> void:
	session.restart_malta()
	await _frames(180)
	_check(session.malta_mission.board_nearest(), "Fresh retry boards serviceable aircraft")
	preload("res://tests/interception_fixture.gd").prepare_final_entry(session) # Explicit activation fixture for isolated result cases.
	await _frames(3)

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)
