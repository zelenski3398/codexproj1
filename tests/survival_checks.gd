extends SceneTree
## Real session lifecycle/damage signals; disclosed pose fixtures isolate airborne
## transitions. These checks do not claim a manual flight or eleven dogfight kills.
var session: Node3D
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	session = preload("res://main.tscn").instantiate()
	root.add_child(session)
	await _frames(3)
	session.show_malta_selection()
	_check(session.malta_menu.mode_picker.item_count == 2 and session.malta_menu.selected_mode == "encounter", "Malta menu preserves default encounters and offers separate Survival")
	for id in ["ta_qali", "luqa", "hal_far"]:
		session.malta_menu.select_field(id)
		session.malta_menu.mode_picker.item_selected.emit(1)
		_check(session.malta_menu.selected_field == id and session.malta_menu.selected_mode == "survival", "Survival is selectable from " + id)
	session.malta_menu.mode_picker.item_selected.emit(0)
	session.malta_menu.depart()
	await _frames(180)
	var mission: MaltaMission = session.malta_mission
	_check(session.game_mode == "encounter" and session.encounters.active.size() == 1, "Existing Malta departure starts exactly one normal encounter")
	_check(mission.board_nearest(), "Boards existing aircraft for airborne transition checks")
	var player: FlightAircraft = session.aircraft
	player.request_reset()
	player.pending_reset_pose = Transform3D(Basis.IDENTITY, player.global_position + Vector3.UP * 200)
	player.pending_reset_velocity = Vector3(0, 0, -70)
	await _frames(4)
	player.pilot.automated = true
	player.pilot.throttle = 0.61
	player.engine_running = true
	player.gear.extended = false
	player.health.take_damage(43)
	player.components.integrity[&"engine"] = 71
	player.components.fuel_remaining = 0.43
	var foe: EnemyAircraft = session.enemy
	foe.ai.combat_enabled = false
	foe.take_damage(51)
	await _frames(3)
	_check(session.encounters.active.size() == 1 and not session.encounters.awaiting_confirmation, "Low HP or damage/smoke cannot clear an encounter")
	foe.take_damage(100)
	foe.take_damage(100)
	_check(session.encounters.active.is_empty() and session.encounters.wrecks.has(foe) and session.defeat_notifications == 1, "Destruction removes active tracking once while retaining a physical wreck")
	_check(session.encounters.awaiting_confirmation, "Kill waits for confirmation rather than auto-spawning")
	await _frames(10)
	_check(session.encounters.active.is_empty(), "Running world stays enemy-free until confirmation")
	var scene_id: int = mission.world.get_instance_id()
	var life: int = session.session_number
	var position: Vector3 = player.global_position
	var velocity: Vector3 = player.linear_velocity
	player.guns.pool.spawn(position + Vector3.UP * 50, Vector3.FORWARD * 10, 20, 1, player.get_rid(), false, player.team_id)
	var rounds: int = player.guns.pool.active.size()
	var echo: InputEventKey = InputEventKey.new()
	echo.keycode = KEY_C
	echo.pressed = true
	echo.echo = true
	Input.parse_input_event(echo)
	_check(session.encounters.awaiting_confirmation, "Held-key repeats do not confirm a cleared stage")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_C
	key.pressed = true
	Input.parse_input_event(key)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	for press in range(8):
		session.encounters.confirm()
	_check(session.encounters.spawning and not session.encounters.awaiting_confirmation and session.encounters.active.is_empty(), "Confirmation latches once before deferred physics-safe spawning")
	await _frames(3)
	_check(session.encounters.active.size() == 1 and session.enemy != foe, "Repeated confirmation spawns exactly one replacement")
	_check(session.malta_mission == mission and mission.world.get_instance_id() == scene_id and session.aircraft == player and session.session_number == life, "Confirmation retains session, continuous world and exact player instance")
	_check(player.global_position.distance_to(position) < 5 and player.linear_velocity.distance_to(velocity) < 5 and not player.reset_pending, "Airborne position and velocity continue through forces without runway reset")
	_check(player.health.hp == 57 and player.components.integrity[&"engine"] == 71 and absf(player.components.fuel_remaining - 0.43) < 0.001 and player.engine_running and not player.gear.extended and player.pilot.throttle == 0.61, "Health, component damage, fuel, engine, gear and throttle persist")
	_check(player.guns.pool.active.size() == rounds and not paused, "Confirmation retains in-flight projectiles and never pauses control")
	_check(session.enemy.global_position.distance_to(player.global_position) >= session.encounters.minimum_spawn_distance, "Replacement spawns safely away from the moving player")
	# Full restart may reset the run; confirmed stage transitions must not.
	session.show_selection()
	session.start_malta("luqa", "spitfire", "survival")
	await _frames(180)
	mission = session.malta_mission
	_check(session.game_mode == "survival" and session.encounters.stage == 1, "New Survival begins at stage one")
	_check(mission.board_nearest(), "Survival starts with the existing boarding flow")
	player = session.aircraft
	player.health.take_damage(20)
	player.components.fuel_remaining = 0.6
	scene_id = mission.world.get_instance_id()
	life = session.session_number
	for stage in range(1, 6):
		var director: EnemyEncounters = session.encounters
		var expected: int = [1, 2, 2, 3, 3][stage - 1]
		_check(director.stage == stage and director.active.size() == expected, "Survival stage %d starts its whole %d-enemy batch" % [stage, expected])
		var aces: int = 0
		var normal: EnemyAircraft
		var ace: EnemyAircraft
		for current in director.active:
			current.ai.combat_enabled = false
			if current.encounter_ace:
				aces += 1
				ace = current
			else:
				normal = current
			var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(current.global_position, current.global_position + Vector3.DOWN * 120, 1)
			_check(current.altitude > 100 and current.global_position.distance_to(player.global_position) > 600 and current.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Stage %d enemy is airborne above terrain/buildings and away from player" % stage)
		for i in range(director.active.size()):
			for j in range(i + 1, director.active.size()):
				_check(director.active[i].global_position.distance_to(director.active[j].global_position) >= director.spawn_separation - 5, "Stage batch aircraft have safe mutual clearance")
		_check(aces == (1 if stage == 5 else 0), "Only final stage contains exactly one ace")
		if stage == 5:
			_check(ace.ai.aim_error_degrees < normal.ai.aim_error_degrees * 0.3 and ace.guns.spread_degrees < normal.guns.spread_degrees * 0.3 and ace.display_name.contains("ACE"), "Ace is labelled and has substantially lower configurable aiming error")
			_check(ace.rear_gunner.skill_level == normal.rear_gunner.skill_level and ace.rear_gunner.rounds_per_second == normal.rear_gunner.rounds_per_second and ace.rear_gunner.burst_duration == normal.rear_gunner.burst_duration and ace.rear_gunner.burst_rest == normal.rear_gunner.burst_rest, "Ace retains existing defensive gunner skill and burst timing")
			_check(normal.ai.aim_error_degrees == 0.18 and normal.guns.spread_degrees == 0.08, "Normal pilot accuracy remains unchanged")
			_check(ace.ai.firing_range == normal.ai.firing_range and ace.guns.rounds_per_second == normal.guns.rounds_per_second and ace.guns.bullet_speed == normal.guns.bullet_speed and ace.guns.bullet_damage == normal.guns.bullet_damage and ace.guns.bullet_lifetime == normal.guns.bullet_lifetime, "Ace retains normal range, firing rate, ballistics, lifetime and damage")
		var victims: Array[EnemyAircraft] = director.active.duplicate()
		if victims.size() > 1:
			victims.pop_back().take_damage(100)
			_check(not director.awaiting_confirmation and director.active.size() == expected - 1, "Partial stage kills never enable confirmation")
		for current in victims:
			current.take_damage(100)
			current.take_damage(100)
		_check(director.active.is_empty(), "Nearly simultaneous destruction events clear stage %d exactly once" % stage)
		_check(player.health.hp == 80 and mission.world.get_instance_id() == scene_id and session.aircraft == player and session.session_number == life and absf(player.components.fuel_remaining - 0.6) < 0.001, "Stage transitions preserve world, aircraft, health and fuel")
		if stage < 5:
			_check(director.awaiting_confirmation and not director.complete, "Stage %d awaits explicit confirmation" % stage)
			await _frames(5)
			_check(director.stage == stage and director.active.is_empty(), "No next stage starts without confirmation")
			for press in range(8):
				director.confirm()
			await _frames(5)
		else:
			_check(director.complete and not director.awaiting_confirmation, "Clearing stage five completes Survival with no sixth stage")
			for press in range(8):
				director.confirm()
			await _frames(5)
			_check(director.stage == 5 and director.active.is_empty() and director.status.text.contains("Survival Complete"), "Final completion is visible and repeated confirmation cannot restart it")
	_check(session.defeat_notifications == 11, "All eleven Survival enemies produce one destruction notification each")
	session.restart_malta()
	await _frames(180)
	_check(session.game_mode == "survival" and session.encounters.stage == 1 and session.encounters.active.size() == 1 and session.encounters.wrecks.is_empty(), "Full restart preserves chosen mode and clears all old enemies/wrecks")
	_check(session.malta_mission.board_nearest(), "Reboards fresh run aircraft")
	session.enemy.take_damage(100)
	session.encounters.confirm()
	session.aircraft.take_damage(100)
	await _frames(5)
	_check(session.encounters.ended and not session.encounters.awaiting_confirmation and session.encounters.active.is_empty() and session.encounters.stage == 1, "Player destruction cancels an already queued next-stage spawn")
	for press in range(8):
		session.encounters.confirm()
	await _frames(5)
	_check(session.encounters.active.is_empty(), "Destroyed player cannot spawn further stages")
	# A queued callback from an old mission cannot mutate a fresh run.
	session.restart_malta()
	await _frames(180)
	session.enemy.take_damage(100)
	session.encounters.confirm()
	session.restart_malta()
	await _frames(180)
	_check(session.encounters.stage == 1 and session.encounters.active.size() == 1, "Queued old confirmation is invalidated by full restart")
	print("SURVIVAL RESULT: ", checks - failures, "/", checks, " passed; ", failures, " failed")
	quit(1 if failures else 0)

func _frames(count: int) -> void:
	for tick in range(count):
		await physics_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
