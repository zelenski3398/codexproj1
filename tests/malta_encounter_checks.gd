extends SceneTree
## Real session/input/destruction paths. Frozen aircraft and an explicit on-foot
## relocation isolate encounter state and safe spawn anchors, not manual flight.
var session: Node3D
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	session = preload("res://main.tscn").instantiate()
	root.add_child(session)
	session.start_malta("ta_qali", "spitfire")
	await frames(180)
	var director: EnemyEncounters = session.encounters
	var mission: MaltaMission = session.malta_mission
	check(director.active.is_empty() and session.enemy == null and director.initial_spawn_pending and director.awaiting_confirmation and not session.enemy_defeated, "Free roam has no initial enemy or false kill message and waits for explicit spawn")
	check(director.confirm_button.visible and director.confirm_button.text.contains("SPAWN RANDOM ENEMY"), "Visible spawn button explains the C alternative")
	await frames(60)
	check(director.active.is_empty(), "Elapsed time alone never spawns an encounter")
	paused = true
	director.confirm()
	check(not director.spawning and director.awaiting_confirmation, "Pause blocks a spawn order")
	paused = false
	key_c(true)
	check(director.initial_spawn_pending and director.awaiting_confirmation, "Key repeat cannot activate the first encounter")
	check(mission.board_nearest(), "Player can board normally before requesting combat")
	var player: FlightAircraft = session.aircraft
	player.freeze = true
	player.pilot.automated = true
	player.pilot.throttle = .57
	player.engine_running = true
	player.take_damage(23)
	player.components.integrity[&"engine"] = 75
	player.components.fuel_remaining = .64
	var world_id: int = mission.world.get_instance_id()
	var player_id: int = player.get_instance_id()
	var position: Vector3 = player.global_position
	var velocity: Vector3 = player.linear_velocity
	player.guns.pool.spawn(position + Vector3.UP * 100, Vector3.RIGHT, 20, 1, player.get_rid(), false, player.team_id)
	director.random.seed = 1942
	key_c()
	for i in range(10): director.confirm_button.pressed.emit()
	await frames(4)
	check(director.active.size() == 1 and director.stage == 1 and not director.initial_spawn_pending, "C plus button spam creates exactly one first encounter")
	check(director.free_roam_enemy_types.has(session.enemy.aircraft_kind), "Spawned hostile belongs to requested four-aircraft roster")
	check(player.get_instance_id() == player_id and mission.world.get_instance_id() == world_id and player.global_position == position and player.linear_velocity == velocity, "Spawning preserves player/world identity, position and velocity")
	check(player.health.hp == 77 and player.components.integrity[&"engine"] == 75 and is_equal_approx(player.components.fuel_remaining, .64) and player.engine_running and is_equal_approx(player.pilot.throttle, .57), "Spawning preserves health, mechanical damage, fuel, engine and throttle")
	check(player.guns.pool.active.size() == 1 and not paused, "Spawning preserves in-flight bullets without pausing controls")
	retire_enemy()
	await frames(5)
	check(director.active.is_empty() and director.awaiting_confirmation, "A kill waits for another command without automatic replacement")
	var original_roster: Array[String] = director.free_roam_enemy_types.duplicate()
	for kind in ["cr42", "c200", "c202", "stuka"]:
		director.free_roam_enemy_types.assign([kind])
		director.confirm()
		await frames(4)
		var enemy: EnemyAircraft = session.enemy
		check(director.active.size() == 1 and enemy.aircraft_kind == kind, kind + " can actually spawn from the configurable roster")
		check(enemy.team_id == CombatTeams.ENEMY and enemy.components.hitboxes.size() == 12 and enemy.guns.pool != null, kind + " retains existing faction, localized damage and swept weapons")
		check(enemy.altitude > director.spawn_clearance and enemy.global_position.distance_to(player.global_position) >= director.minimum_spawn_distance, kind + " spawns airborne with player/terrain clearance")
		if kind == "stuka":
			check(enemy.guns.rounds_per_second == 6 and enemy.guns.bullet_damage == 2 and enemy.ai.cruise_speed == 58, "Italian encounters do not contaminate subsequent Stuka difficulty")
		retire_enemy()
		await frames(4)
	director.free_roam_enemy_types = original_roster
	director.random.seed = 1942
	var seen: Dictionary = {}
	for i in range(1000):
		var kind: String = director._enemy_kind(0)
		seen[kind] = int(seen.get(kind, 0)) + 1
	check(seen.size() == 4 and seen.values().all(func(n): return n > 150 and n < 350), "Seeded random selection reaches all four types without fixed stage cycling")
	player.engine_running = false
	player.pilot.throttle = 0
	check(mission.leave_aircraft(), "Existing stopped-ground exit remains available")
	mission.pilot.global_position = mission.world.fields.luqa.pilot_spawn # disclosed travel fixture
	director.confirm()
	await frames(4)
	check(session.enemy.global_position.distance_to(mission.pilot.global_position) < 2000 and session.enemy.global_position.distance_to(player.global_position) > 2200, "On-foot request spawns near current player location rather than abandoned home aircraft")
	retire_enemy()
	director.confirm()
	session.restart_malta()
	await frames(60)
	check(session.enemy == null and director.active.is_empty() and director.initial_spawn_pending and director.awaiting_confirmation, "Retry invalidates queued orders and returns to peaceful free roam")
	check(director.wrecks.is_empty() and session.malta_mission.fleet.all(func(a): return a.health.hp == 100), "Retry clears old wrecks and restores the fleet")
	director.confirm()
	session.aircraft.take_damage(100)
	await frames(4)
	check(director.ended and director.active.is_empty() and not director.awaiting_confirmation, "Player loss cancels a queued first spawn")
	session.show_selection()
	session.start_flight("spitfire")
	await frames(4)
	check(director.active.size() == 1 and session.enemy.aircraft_kind == "stuka", "Countryside retains its immediate Stuka encounter")
	session.show_selection()
	session.start_malta("hal_far", "sea_gladiator", "survival")
	await frames(30)
	check(director.active.size() == 1 and director.stage == 1 and session.enemy.aircraft_kind == "stuka" and not director.initial_spawn_pending, "Survival retains its immediate stage one and unchanged Stuka roster")
	session.queue_free()
	await frames(4)
	print("MALTA ENCOUNTERS RESULT: ", checks-failures, "/", checks, " passed; ", failures, " failed")
	quit(1 if failures else 0)

func retire_enemy() -> void:
	var foe: EnemyAircraft = session.enemy
	foe.freeze = true
	foe.ai.set_physics_process(false)
	foe.rear_gunner.cease_fire()
	foe.take_damage(1000)

func key_c(echo: bool = false) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_C
	key.pressed = true
	key.echo = echo
	Input.parse_input_event(key)
	key = key.duplicate()
	key.pressed = false
	key.echo = false
	Input.parse_input_event(key)

func frames(count: int) -> void:
	for tick in range(count): await physics_frame

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition: print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)
