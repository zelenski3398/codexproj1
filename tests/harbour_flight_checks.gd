extends SceneTree
## Player airborne start fixture only. Wingmen take off from real Hal Far runway;
## bomber navigates and payload falls with shared physical simulation thereafter.
var session: Node3D
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("_run")
func _check(value: bool, text: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", text)
func _frames(n: int) -> void:
	for i in n: await physics_frame
func _run() -> void:
	session = preload("res://main.tscn").instantiate()
	root.add_child(session)
	session.start_harbour()
	await _frames(180)
	_check(session.malta_mission.board_nearest(), "Board Faith normally")
	var faith: FlightAircraft = session.aircraft
	var mission: HarbourInterception = session.harbour
	faith.request_reset()
	faith.pending_reset_pose = Transform3D(Basis.IDENTITY, faith.global_position + Vector3.UP * 400)
	faith.pending_reset_velocity = Vector3.FORWARD * 50
	faith.engine_running = true
	faith.pilot.automated = true
	var steering := EnemyPilot.new()
	steering.aircraft = faith
	steering.measured_terrain = true
	steering.world_extent = INF
	steering.minimum_agl = 100
	steering.cruise_speed = 52
	var airborne: Dictionary = {}
	var impacts: Array[Vector3] = []
	var first_wave_frame: int = -1
	for tick in 37000:
		if not faith.reset_pending and not faith.is_destroyed:
			steering._scan_terrain()
			steering._fly_toward(Vector3(9500,520,8500), 1.0/120)
		await physics_frame
		if mission.wave > 0 and first_wave_frame < 0:
			first_wave_frame = tick
			_check(tick >= 710 and tick <= 750 and mission.wave_spawn_counts == [4], "Actual airborne gate activates once after six seconds, independent of wingmen")
			print("SPAWN_DISTANCE=",faith.global_position.distance_to(mission.bomber.global_position)," BOMBER_ROUTE=",mission.bomber.ai.route_start.distance_to(mission.bomber.ai.route_end))
			# Isolate flight and bombing from random gunfire; no navigation bypass.
			for foe in session.encounters.active:
				foe.ai.combat_enabled = false
				foe.guns.rounds_per_second = 0
				foe.rear_gunner.enabled = false
				for gunner in (foe as ItalianEnemy).additional_gunners: gunner.enabled = false
			for friend in mission.wingmen: friend.guns.rounds_per_second = 0
		for friend in mission.wingmen:
			if is_instance_valid(friend) and not friend.is_destroyed and friend.altitude > 60: airborne[friend.callsign] = true
		for effect in mission.effects.get_children():
			if effect is MissionBomb and not effect.has_meta("watched"):
				effect.set_meta("watched",true)
				effect.impacted.connect(func(p:Vector3):impacts.append(p))
		if tick % 6000 == 0:
			print("t=",tick/120.0," phase=",mission.phase," wave=",mission.wave," friends=",airborne," hp=",faith.health.hp)
			for friend in mission.wingmen:
				if is_instance_valid(friend):print(friend.callsign," agl=",friend.altitude," speed=",friend.airspeed," crashed=",friend.is_crashed," at=",friend.global_position)
		if mission.bombs_released == mission.definition.payload_count and impacts.size() >= mission.definition.payload_count: break
	_check(airborne.has("Hope") and airborne.has("Charity"), "Both wingmen take off through real runway/force physics")
	_check(mission.phase == "FAILED" and mission.payload_released and mission.bombs_released == 4, "Unintercepted physical bomber reaches release and fails once")
	_check(impacts.size() == 4, "All four bombs register swept world impacts")
	var closest: float = INF
	for point in impacts: closest = minf(closest,mission.forts[0].blast_distance(point))
	print("BOMB_IMPACT_CLOSEST_FORT_METRES=",closest," ST_ELMO_HP=",mission.forts[0].hp," simulated_seconds=",Engine.get_physics_frames()/120.0)
	_check(closest < mission.definition.bomb_blast_radius and mission.forts[0].hp < 1000, "Actual bomb trajectories hit/damage selected geographic fort")
	_check(mission.result_count == 1 and mission.wave == 1, "Release failure cannot duplicate results or spawn another wave")
	print("HARBOUR FLIGHT RESULT: ",checks-failures,"/",checks," passed")
	steering.free()
	session.queue_free()
	await _frames(5)
	quit(1 if failures else 0)
