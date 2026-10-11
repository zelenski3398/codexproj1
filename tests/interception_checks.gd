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
	player.request_reset()
	player.pending_reset_pose = Transform3D(Basis.IDENTITY, mission.definition.checkpoint)
	player.pending_reset_velocity = Vector3(0, 0, -65)
	player.pilot.automated = true
	await _frames(5)
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
	_check(session.interception.phase == "CHECKPOINT" and session.interception.elapsed == 0 and session.encounters.active.is_empty() and session.encounters.wrecks.is_empty(), "Retry restores checkpoint gating with no old foes/timer/wrecks")
	session.return_to_missions()
	await _frames(3)
	_check(session.missions_menu != null and session.interception == null and session.malta_mission == null, "Return to Missions cleans mission and reopens briefing")
	# Returning/retrying in the same tick as a last kill must invalidate old callbacks.
	session.start_interception("spitfire")
	await _frames(180)
	session.interception.activate()
	await _frames(3)
	session.interception.bomber.take_damage(100)
	session.interception.escort.take_damage(100)
	session.restart_malta()
	await _frames(180)
	_check(session.interception.phase == "CHECKPOINT" and not session.encounters.ended and session.interception.result_count == 0, "Old deferred resolution cannot finish a fresh retry")
	session.interception.activate()
	await _frames(3)
	session.interception.bomber.take_damage(100)
	session.interception.escort.take_damage(100)
	await _frames(2)
	_check(session.interception.success and session.interception.result_count == 1, "Simultaneous pre-deadline kills produce one success")
	session.return_to_missions()
	await _frames(3)
	# CR.42 escort variation uses the same mission; no count or default-mode changes.
	session.start_interception("sea_gladiator")
	await _frames(180)
	_check(session.aircraft is SeaGladiator and not session.aircraft.engine_running, "Gladiator mission keeps its ground/manual-engine start")
	session.interception.definition = session.interception.definition.duplicate()
	session.interception.definition.escort_type = "cr42"
	session.interception.activate()
	await _frames(3)
	_check(session.interception.escort.aircraft_kind == "cr42", "Escort definition supports a future CR.42 variant")
	session.queue_free()
	await _frames(3)
	print("INTERCEPTION CHECKS: ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)

func _record_impact(point: Vector3, positions: Array[Vector3]) -> void:
	positions.append(point)

func _restart_activate() -> void:
	session.restart_malta()
	await _frames(180)
	_check(session.malta_mission.board_nearest(), "Fresh retry boards serviceable aircraft")
	session.interception.activate() # Explicit activation fixture for isolated result cases.
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
