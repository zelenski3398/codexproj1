extends SceneTree
## Real dispersed/swept bullets against frozen intact silhouettes; separate
## moving trials and attacks use ordinary rigid-body controls. No fake hits.
var world: Node3D
var player: FlightAircraft
var enemy: EnemyAircraft
var checks: int = 0
var failures: int = 0
var records: Array[Dictionary] = []
var movement_records: Array[Dictionary] = []
var current_kind: String = "spitfire"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.start_flight(current_kind)
	player = world.aircraft
	player.pilot.automated = true
	await _frames(8)
	enemy = world.enemy
	_check(enemy.rear_gunner.bullet_damage == 1.5 and enemy.rear_gunner.bullet_speed == 765 and enemy.rear_gunner.bullet_lifetime == 1.15, "Rear damage, speed and lifetime remain unchanged")
	_check(player.guns.bullet_damage == 4 and player.guns.bullet_speed == 850 and player.guns.convergence_distance == 250, "Player damage, speed and convergence remain unchanged")
	var source: String = FileAccess.get_file_as_string("res://scripts/rear_gunner.gd")
	_check(not source.contains("target.linear_velocity") and not source.contains("target.components") and not source.contains("engagement_range"), "No exact target velocity, component-specific aim or artificial range cutoff")
	var run_accuracy: bool = not OS.get_cmdline_user_args().has("--quick")
	for kind in (["spitfire", "sea_gladiator"] if run_accuracy else []):
		if kind != current_kind:
			world.show_selection()
			world.start_flight(kind)
			player = world.aircraft
			player.pilot.automated = true
			current_kind = kind
			await _frames(6)
		for skill in range(3):
			for distance in [100.0, 300.0, 500.0, 700.0]:
				var shots: int = 0
				var hits: int = 0
				var parts: Dictionary = {}
				var minimum_time: float = INF
				for seed_value in [1943, 7, 29]:
					await _fixture(distance, skill, seed_value)
					for tick in range(2400):
						_keep_intact()
						await physics_frame
						var stat: WeaponStatistics = enemy.rear_gunner.guns.pool.statistics
						if stat.aircraft_hits > 0:
							minimum_time = minf(minimum_time, stat.last_flight_time)
					var statistics: WeaponStatistics = enemy.rear_gunner.guns.pool.statistics
					shots += statistics.shots
					hits += statistics.aircraft_hits
					for id in statistics.component_hits:
						parts[id] = int(parts.get(id, 0)) + int(statistics.component_hits[id])
					_check(statistics.shots == enemy.rear_gunner.guns.pool.total_spawned and statistics.aircraft_hits <= statistics.shots, "%s/%d/%dm/seed%d: accepted shot and actual hit counters" % [kind, skill, distance, seed_value])
				var percentage: float = 100.0 * hits / maxf(shots, 1)
				var row: Dictionary = {"aircraft": kind, "skill": skill, "distance": distance, "shots": shots, "hits": hits, "percentage": percentage, "components": parts}
				records.append(row)
				print("BALANCE ", JSON.stringify(row))
				_check(shots > 0, "%s/%d: %dm permits shots, including beyond 500 m" % [kind, skill, distance])
				if hits > 0:
					_check(minimum_time > distance / 765 * 0.7, "%s/%d/%dm: real projectile travel time" % [kind, skill, distance])
			_check(float(_row(kind, skill, 100).percentage) > float(_row(kind, skill, 500).percentage) * 2 + 5, "%s/%d: accuracy decreases naturally with range" % [kind, skill])
			_check(float(_row(kind, skill, 500).percentage) < 22, "%s/%d: 500 m hits are uncommon" % [kind, skill])
		_check(float(_row(kind, 1, 100).percentage) > 25 and float(_row(kind, 2, 100).percentage) > 35, kind + ": close tail following remains dangerous")
		_check(int(_row(kind, 1, 500).hits) > 0 and int(_row(kind, 2, 700).hits) > 0, kind + ": long-range hits remain possible")
		_check(float(_row(kind, 0, 100).percentage) < float(_row(kind, 1, 100).percentage) and float(_row(kind, 1, 100).percentage) < float(_row(kind, 2, 100).percentage), kind + ": graded Cadet/Pilot/Ace close accuracy")

	await _fixture(300, 1, 1943)
	var gunner: RearGunner = enemy.rear_gunner
	await _frames(30)
	_check(gunner.guns.pool.statistics.shots == 0 and gunner.observation_count > 0, "Observation and reaction precede firing")
	await _frames(240)
	_check(gunner.observation_count > 2 and gunner.aim_bias.length() > 0 and gunner.guns.pool.statistics.shots > 0, "Human observations and judgement errors remain active")
	_check(gunner.aim_point.distance_to(player.global_position) > 0.1, "Whole-aircraft aiming retains error rather than engine lock")
	var biased: Vector2 = gunner.aim_bias
	await _frames(240)
	_check(not gunner.aim_bias.is_equal_approx(biased), "Burst-to-burst judgement corrections")

	for id in [&"rudder", &"elevator", &"left_wing", &"right_wing", &"fuselage"]:
		var spec: DamageHitboxSpec = enemy.components.definitions[id].hitboxes[0]
		var origin: Vector3 = gunner.muzzle().global_position
		var direction: Vector3 = (enemy.to_global(spec.position) - origin).normalized()
		_check(not gunner.shot_has_clearance(origin, direction), "Dispersed shot safety blocks own " + String(id))
	_check(gunner.shot_has_clearance(gunner.muzzle().global_position, (player.global_position - gunner.muzzle().global_position).normalized()), "Clear rear-quarter trajectory remains available")
	var stat_before: int = gunner.guns.pool.statistics.shots
	gunner.guns.shot_clearance = func(_origin: Vector3, _direction: Vector3) -> bool: return false
	gunner.guns._fire_salvo()
	_check(gunner.guns.pool.statistics.shots == stat_before, "Rejected dispersed shots create no projectile or false counter")
	gunner.guns.shot_clearance = Callable(gunner, "shot_has_clearance")
	gunner.enabled = false
	gunner.guns.pool.clear()
	var maximum_spread: float = 0
	var barrel: Vector3 = -gunner.muzzle().global_basis.z
	for round_index in range(32):
		gunner.guns._fire_salvo()
	for slot in gunner.guns.pool.active:
		var velocity: Vector3 = gunner.guns.pool.velocities[slot] - enemy.linear_velocity
		maximum_spread = maxf(maximum_spread, velocity.normalized().angle_to(barrel))
	_check(gunner.guns.pool.statistics.shots == 32 and maximum_spread > deg_to_rad(0.02) and maximum_spread <= deg_to_rad(gunner.guns.spread_degrees * 1.5), "Actual round dispersion varies trajectories within the configured cone")
	gunner.guns.pool.clear()
	gunner.guns.pool.spawn(player.to_global(Vector3(20, 0, 2.2)), -player.global_basis.x * 100, 1, 2, enemy.get_rid(), true, enemy.team_id, 20)
	gunner.guns.pool.statistics.reset()
	await _frames(40)
	_check(gunner.guns.pool.statistics.shots == 0 and gunner.guns.pool.statistics.aircraft_hits == 0, "Counter reset excludes previously airborne rounds")

	await _fixture(200, 1, 1943, false)
	var moving_start: Vector3 = player.global_position
	var maximum_angular_motion: float = 0
	var maximum_motion_penalty: float = 0
	for tick in range(1440):
		_keep_intact()
		player.pilot.roll = 0.7 * sin(tick / 120.0 * 1.4)
		player.pilot.pitch = clampf((0.02 + (224 - player.global_position.y) * 0.008 - player.rotation.x) * 4, -0.6, 0.6)
		enemy.pilot.roll = 0.5 * sin(tick / 120.0 * 0.8)
		enemy.pilot.pitch = clampf((0.02 + (200 - enemy.global_position.y) * 0.008 - enemy.rotation.x) * 4, -0.6, 0.6)
		await physics_frame
		maximum_angular_motion = maxf(maximum_angular_motion, enemy.rear_gunner.angular_motion)
		maximum_motion_penalty = maxf(maximum_motion_penalty, enemy.rear_gunner.motion_penalty_degrees)
	_check(not enemy.is_destroyed and player.global_position.distance_to(moving_start) > 300 and maximum_angular_motion > 0.04, "Actual weaving flight creates target angular motion")
	_check(maximum_motion_penalty > 0.08 and enemy.rear_gunner.guns.pool.statistics.shots > 0, "Stuka manoeuvres penalize accuracy without disabling rear fire")
	print("MOVING angular=", maximum_angular_motion, " motion penalty=", maximum_motion_penalty, " shots=", enemy.rear_gunner.guns.pool.statistics.shots, " hits=", enemy.rear_gunner.guns.pool.statistics.aircraft_hits)
	world.component_debug.set_enabled(true)
	var panel: GunnerDebugPanel = world.component_debug.gunner_panel
	panel.skill_picker.item_selected.emit(0)
	_check(enemy.rear_gunner.skill_level == 0 and enemy.rear_gunner.skill_override == null and not enemy.rear_gunner.firing, "F3 changes human skill and requires reacquisition")
	await process_frame
	panel._process(1)
	_check(panel.counters.text.contains("shots") and panel.counters.text.contains("Parts:") and panel.perception.text.contains("range"), "F3 exposes shots, hits, percentage, range and components")
	panel.reset_statistics()
	_check(enemy.rear_gunner.guns.pool.statistics.shots == 0 and player.guns.pool.statistics.shots == 0, "Debug counter reset affects both sides without repairing damage")
	enemy.guns._fire_salvo()
	var retained_shots: int = enemy.guns.pool.statistics.shots
	enemy.take_damage(100)
	panel._process(1)
	_check(retained_shots > 0 and world.enemy_front_statistics.shots == retained_shots and enemy.guns.pool.active.is_empty() and panel.perception.text.contains("DESTROYED"), "Destruction clears bullets while retaining session weapon statistics")
	await _movement_comparison()
	await _player_attack("spitfire")
	await _player_attack("sea_gladiator")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = args[0] if not args.is_empty() else "user://gunner_balance_results.json"
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"static": records, "moving": movement_records}, "\t"))
	print("GUNNER BALANCE RESULT: ", checks - failures, "/", checks, " passed; ", failures, " failed; data=", output)
	quit(1 if failures else 0)

func _movement_comparison() -> void:
	for weaving in [false, true]:
		var shots: int = 0
		var hits: int = 0
		var angle_sum: float = 0
		var range_sum: float = 0
		for seed_value in [1943, 7, 29]:
			await _fixture(300, 1, seed_value, false)
			for tick in range(1440):
				_keep_intact()
				player.pilot.roll = 0.8 * sin(tick / 120.0 * 1.1) if weaving else -player.rotation.z * 2
				player.pilot.pitch = clampf((0.04 + (236 - player.global_position.y) * 0.008 - player.rotation.x) * 4, -0.6, 0.6)
				enemy.pilot.roll = -enemy.rotation.z * 2
				enemy.pilot.pitch = clampf((0.02 + (200 - enemy.global_position.y) * 0.008 - enemy.rotation.x) * 4, -0.6, 0.6)
				await physics_frame
				angle_sum += enemy.rear_gunner.angular_motion
				range_sum += enemy.rear_gunner.engagement_distance
			shots += enemy.rear_gunner.guns.pool.statistics.shots
			hits += enemy.rear_gunner.guns.pool.statistics.aircraft_hits
		var row: Dictionary = {"aircraft": current_kind, "weaving": weaving, "shots": shots, "hits": hits, "percentage": 100.0 * hits / maxf(shots, 1), "mean_angular_motion": angle_sum / (1440 * 3), "mean_distance": range_sum / (1440 * 3)}
		movement_records.append(row)
		print("MOVEMENT ", JSON.stringify(row))
	_check(float(movement_records[1].mean_angular_motion) > float(movement_records[0].mean_angular_motion) * 1.5, "Real evasive controls increase target angular movement")
	_check(int(movement_records[1].shots) > 0 and float(movement_records[1].percentage) < float(movement_records[0].percentage), "Real evasive movement reduces measured Pilot hit percentage")

func _player_attack(kind: String) -> void:
	world.show_selection()
	world.start_flight(kind)
	current_kind = kind
	player = world.aircraft
	player.pilot.automated = true
	await _fixture(180, 1, 7, false)
	var npc_position: Vector3 = enemy.global_position
	var offset: Vector3 = Vector3(40, 6, 175)
	var bearing: Basis = Basis.looking_at(-offset + Vector3(0, 0, -5), Vector3.UP)
	player.request_reset()
	player.pending_reset_pose = Transform3D(bearing, npc_position + offset)
	player.pending_reset_velocity = -bearing.z * 65
	await _frames(6)
	enemy = world.enemy
	enemy.ai.combat_enabled = false
	enemy.request_reset()
	enemy.pending_reset_pose = Transform3D(Basis.IDENTITY, npc_position)
	enemy.pending_reset_velocity = Vector3(0, 0, -55)
	await _frames(6)
	enemy.ai.set_physics_process(false)
	enemy.ai.combat_unlocked = true
	enemy.ai.grace_period = 0
	enemy.ai.combat_enabled = true
	enemy.rear_gunner.set_skill(1)
	enemy.pilot.throttle = 0.6
	player.pilot.throttle = 0.7
	player.gear.extended = false
	player.pilot.fire = true
	for tick in range(2400):
		if enemy.is_destroyed or player.is_destroyed:
			break
		# A test pilot tracks the moving/wounded silhouette using ordinary
		# torque-producing controls; player guns retain their normal aim.
		var flight_time: float = player.global_position.distance_to(enemy.global_position) / player.guns.bullet_speed
		var point: Vector3 = enemy.global_position + (enemy.linear_velocity - player.linear_velocity) * flight_time
		var local: Vector3 = player.global_basis.transposed() * (point - player.global_position)
		var omega: Vector3 = player.global_basis.transposed() * player.angular_velocity
		player.pilot.pitch = clampf(atan2(local.y, -local.z) * 5 - omega.x * 0.5, -1, 1)
		var heading_error: float = atan2(-local.x, -local.z)
		player.pilot.rudder = clampf(heading_error * 0.3 - omega.y * 0.5, -0.4, 0.4)
		var wanted_bank: float = clampf(heading_error * 1.4, -0.8, 0.8)
		player.pilot.roll = clampf((wanted_bank - asin(player.global_basis.x.y)) * 4 - omega.z * 0.5, -1, 1)
		await physics_frame
	player.pilot.fire = false
	_check(enemy.is_destroyed and not player.is_destroyed and player.guns.pool.statistics.aircraft_hits > 0 and enemy.rear_gunner.guns.pool.total_spawned > 0, kind + ": physical forward fire defeats a Stuka with an active rear gunner")
	print("ATTACK ", kind, " enemyHP=", enemy.health.hp, " playerHP=", player.health.hp, " playerHits=", player.guns.pool.statistics.aircraft_hits, " rearShots=", enemy.rear_gunner.guns.pool.total_spawned)

func _fixture(distance: float, skill: int, seed_value: int, static_fixture: bool = true) -> void:
	player.freeze = false
	player.request_reset()
	var offset: Vector3 = Vector3(distance * 0.2, distance * 0.12, distance * sqrt(1 - 0.2 * 0.2 - 0.12 * 0.12))
	player.pending_reset_pose = Transform3D(Basis.IDENTITY, Vector3(0, 200, 0) + offset)
	player.pending_reset_velocity = Vector3.ZERO if static_fixture else Vector3(0, 0, -55)
	await _frames(6)
	enemy = world.enemy
	enemy.ai.combat_enabled = false
	enemy.request_reset()
	enemy.pending_reset_pose = Transform3D(Basis.IDENTITY, Vector3(0, 200, 0))
	enemy.pending_reset_velocity = Vector3.ZERO if static_fixture else Vector3(0, 0, -55)
	await _frames(6)
	enemy.ai.set_physics_process(false)
	enemy.ai.combat_enabled = true
	enemy.ai.combat_unlocked = true
	enemy.ai.grace_period = 0
	enemy.pilot.reset_commands()
	enemy.pilot.throttle = 0.6
	player.pilot.throttle = 0.6
	enemy.rear_gunner.enabled = true
	enemy.rear_gunner.aim_seed = seed_value
	enemy.rear_gunner.set_skill(skill)
	enemy.rear_gunner.reset()
	player.freeze = static_fixture
	enemy.freeze = static_fixture

func _keep_intact() -> void:
	player.health.heal(100)
	for id in player.components.definitions:
		player.components.integrity[id] = player.components.definitions[id].max_integrity

func _row(kind: String, skill: int, distance: float) -> Dictionary:
	for row in records:
		if row.aircraft == kind and row.skill == skill and row.distance == distance:
			return row
	return {}

func _frames(count: int) -> void:
	for tick in range(count):
		await physics_frame

func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
