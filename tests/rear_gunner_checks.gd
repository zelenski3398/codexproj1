extends SceneTree
## Real scene, physics, gun mount, shared swept projectiles and session restart.
## Frozen reset fixtures isolate arcs/cover; moving trials validate actual combat.
var world: Node3D
var player: FlightAircraft
var enemy: EnemyAircraft
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.start_flight("spitfire")
	player = world.aircraft
	player.pilot.automated = true
	await _frames(10)
	enemy = world.enemy
	_check(enemy.model.gun_ports.size() == 2 and enemy.rear_gunner.guns.firing_ports.size() == 1, "Rear mount is independent of the two forward wing guns")
	var model: StukaModel = enemy.model as StukaModel
	_check(model.rear_mount.position.z > 1 and model.rear_mount.position.z < 3 and model.rear_muzzle.position.z > 0, "Rear gun and crew occupy the back cockpit, not the nose or tail tip")
	_check(enemy.rear_gunner.engagement_range == 500 and enemy.rear_gunner.guns.pool.capacity == 128, "Provisional 500 m cutoff and fixed shared projectile pool are configurable")
	await _frames(240)
	_check(enemy.rear_gunner.guns.pool.total_spawned == 0 and player.health.hp == 100, "Parked player is protected from both gun stations")
	await _fixture(Vector3(50, 35, 250))
	enemy.ai.reset()
	enemy.ai.grace_period = 8
	enemy.ai.set_physics_process(true)
	await _frames(840)
	_check(not enemy.ai.combat_unlocked and enemy.rear_gunner.guns.pool.total_spawned == 0 and player.health.hp == 100, "Eight-second airborne grace also protects a player in the rear firing sector")
	await _frames(240)
	_check(enemy.ai.combat_unlocked and enemy.rear_gunner.guns.pool.total_spawned > 0, "Rear gunner becomes active after the shared airborne grace unlocks")

	await _fixture(Vector3(50, 35, 250))
	var gunner: RearGunner = enemy.rear_gunner
	await _frames(180)
	_check(gunner.guns.pool.total_spawned > 0 and gunner.guns.pool.total_hits > 0 and player.health.hp < 100, "Actual rear-cockpit bullets hit and damage a following player")
	_check(player.components.last_hit != &"" and enemy.health.hp == 100, "Rear rounds reuse localized damage and exclude their owner's body and sensors")
	_check(gunner.guns.shot_direction(gunner.muzzle()).dot(enemy.global_basis.z) > 0.8, "Rear gun fires along its swivelling muzzle toward local +Z")
	_check(gunner.guns.pool.active.size() <= 128 and gunner.guns.pool.dropped_rounds == 0, "Sustained rear fire remains inside its fixed pool")
	_check(not gunner.guns.use_assisted_aim, "Rear bullets follow the actual smoothly rotated barrel without aim snapping")

	await _fixture(Vector3(60, 50, 493))
	gunner = enemy.rear_gunner
	await _frames(180)
	_check(gunner.guns.pool.total_spawned > 0, "Rear gun engages just inside 500 m")
	await _fixture(Vector3(60, 50, 500))
	gunner = enemy.rear_gunner
	await _frames(180)
	_check(gunner.guns.pool.total_spawned == 0 and gunner.status == "OUT OF RANGE", "Rear gun stays silent just outside 500 m")
	gunner.engagement_range = enemy.global_position.distance_to(player.global_position)
	await _frames(180)
	_check(gunner.guns.pool.total_spawned > 0, "The configured engagement boundary is inclusive")

	await _fixture(Vector3(50, 35, -250))
	await _frames(180)
	_check(enemy.rear_gunner.guns.pool.total_spawned == 0 and enemy.rear_gunner.status == "OUTSIDE REAR ARC", "Rear gun cannot shoot through the nose at a front approach")
	await _fixture(Vector3(300, 35, 50))
	await _frames(180)
	_check(enemy.rear_gunner.guns.pool.total_spawned == 0, "Rear gun respects horizontal traverse limits")
	await _fixture(Vector3(0, 250, 50))
	await _frames(180)
	_check(enemy.rear_gunner.guns.pool.total_spawned == 0, "Rear gun respects elevation limits")
	await _fixture(Vector3(0, 0, 250))
	await _frames(180)
	_check(enemy.rear_gunner.guns.pool.total_spawned == 0 and enemy.rear_gunner.status == "BLOCKED", "Own rudder/fuselage obstruct centreline shots rather than being fired through")
	await _fixture(Vector3(50, 35, 250), true, Basis(Vector3.UP, 0.8) * Basis(Vector3.FORWARD, 0.35))
	await _frames(180)
	_check(enemy.rear_gunner.guns.pool.total_hits > 0, "Rear tracking and swept hits work on a banked, rotated aircraft")

	await _fixture(Vector3(50, 35, 250))
	gunner = enemy.rear_gunner
	var cover: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(80, 80, 4)
	collision.shape = box
	cover.add_child(collision)
	world.add_child(cover)
	cover.position = (enemy.global_position + player.global_position) * 0.5
	await _frames(180)
	_check(gunner.status == "BLOCKED" and gunner.guns.pool.total_spawned == 0 and player.health.hp == 100, "Terrain/buildings prevent rear-gunner trigger and damage")
	# Actual bullet collision also blocks cover if it appears after a shot.
	gunner.guns.pool.spawn(gunner.muzzle().global_position, (player.global_position - gunner.muzzle().global_position).normalized() * 30000, 0.04, 20, enemy.get_rid(), true, enemy.team_id)
	await _frames(5)
	_check(player.health.hp == 100 and gunner.guns.pool.total_hits > 0, "A 30,000 m/s rear round sweeps into cover instead of tunnelling")
	cover.queue_free()
	await _frames(180)
	_check(gunner.guns.pool.total_spawned > 1 and player.health.hp < 100, "Rear gun resumes after its line of sight clears")

	await _fixture(Vector3(50, 35, 250))
	player.team_id = CombatTeams.ENEMY
	await _frames(180)
	_check(enemy.rear_gunner.status == "FRIENDLY" and enemy.rear_gunner.guns.pool.total_spawned == 0, "Gunner refuses a friendly target")
	player.team_id = CombatTeams.PLAYER
	await _frames(180)
	_check(enemy.rear_gunner.guns.pool.total_spawned > 0, "Hostile-team restoration permits rear fire")

	await _fixture(Vector3(160, 40, 200))
	gunner = enemy.rear_gunner
	gunner.tracking_rate_degrees = 5
	var old_yaw: float = gunner.yaw
	await _frames(1)
	_check(absf(gunner.yaw - old_yaw) <= deg_to_rad(5) / 120 + 0.0001 and gunner.guns.pool.total_spawned == 0, "Traverse is rate limited and the gun cannot instantly rotate/fire")
	gunner.tracking_rate_degrees = 75
	await _frames(240)
	_check(gunner.guns.pool.total_spawned > 0, "Normal traverse tracks a rear-quarter approach")
	gunner.burst_clock = gunner.burst_duration + 0.1
	var count: int = gunner.guns.pool.total_spawned
	await _frames(30)
	_check(not gunner.firing and gunner.guns.pool.total_spawned == count, "Rear gun rests between bounded bursts")
	gunner.burst_clock = 0
	await _frames(30)
	_check(gunner.guns.pool.total_spawned > count, "Rear gun resumes a short burst after cooldown")

	# Both airframes now move under ordinary flight forces; their shared velocity
	# is inherited by bullets and lateral motion is predicted by the rear mount.
	await _fixture(Vector3(55, 35, 250), false)
	player.pilot.throttle = 0.6
	enemy.pilot.throttle = 0.7
	var enemy_start: Vector3 = enemy.global_position
	var player_start: Vector3 = player.global_position
	for tick in range(180):
		player.pilot.pitch = clampf((0.02 - player.rotation.x) * 4, -0.5, 0.5)
		enemy.pilot.pitch = clampf((0.02 - enemy.rotation.x) * 4, -0.5, 0.5)
		await physics_frame
	_check(enemy.global_position.distance_to(enemy_start) > 50 and player.global_position.distance_to(player_start) > 50 and enemy.rear_gunner.guns.pool.total_hits > 0, "Rear fire damages a moving pursuer while both aircraft fly through physics")
	_check(enemy.health.hp == 100 and not enemy.is_destroyed, "Moving rear fire cannot damage the Stuka itself")

	await _fixture(Vector3(50, 35, 250))
	enemy.components.apply_damage(&"cockpit", 40)
	await _frames(120)
	_check(not enemy.is_destroyed and enemy.rear_gunner.status == "CREW DISABLED" and enemy.rear_gunner.guns.pool.total_spawned == 0, "Shared cockpit failure disables the gunner before hull destruction")
	enemy.components.reset()
	enemy.health.heal(100)
	await _frames(120)
	_check(enemy.rear_gunner.guns.pool.total_spawned > 0, "Live cockpit repair restores rear-gunner operation")
	var rounds: int = enemy.rear_gunner.guns.pool.total_spawned
	enemy.take_damage(100)
	await _frames(120)
	_check(enemy.is_destroyed and not enemy.rear_gunner.firing and enemy.rear_gunner.guns.pool.total_spawned == rounds, "Destruction disables rear firing once")

	await _fixture(Vector3(50, 35, 250))
	await _frames(90)
	gunner = enemy.rear_gunner
	var clock: float = gunner.burst_clock
	rounds = gunner.guns.pool.total_spawned
	paused = true
	for tick in range(15):
		await process_frame
	_check(gunner.burst_clock == clock and gunner.guns.pool.total_spawned == rounds, "Pause freezes gunner traversal, burst timing and projectiles")
	paused = false
	gunner.engagement_range = 625
	var old_enemy: EnemyAircraft = enemy
	player.freeze = false
	player.request_reset()
	await _frames(12)
	enemy = world.enemy
	_check(enemy != old_enemy and enemy.rear_gunner.guns.pool.active.is_empty() and enemy.rear_gunner.engagement_range == 625, "Full R creates one fresh rear gunner, clears rounds and preserves tuning")
	_check(not enemy.ai.combat_unlocked and not enemy.ai.tracking_target and enemy.rear_gunner.status == "WAITING FOR TAKEOFF", "Full R restores the takeoff grace and clears combat memory")

	# Acquisition regressions that previously excluded slow/low climbing players.
	await _fixture(Vector3(0, 0, -1200))
	enemy.rear_gunner.enabled = false
	enemy.ai.reset()
	enemy.ai.grace_period = 0.5
	enemy.ai.set_physics_process(true)
	await _frames(70)
	_check(player.airspeed < 35 and enemy.ai.mode == "ENGAGE" and enemy.ai.tracking_target, "Slow airborne target unlocks pursuit without the old 126 km/h gate")
	enemy.ai.detection_range = 100
	await _frames(10)
	_check(enemy.ai.mode == "ENGAGE" and enemy.ai.tracking_target, "Acquired player remains pursued outside the initial detection radius")
	enemy.ai.pursuit_release_range = 500
	await _frames(10)
	_check(not enemy.ai.tracking_target and enemy.ai.mode == "PATROL", "Configurable pursuit release range ends a lost encounter")

	# Tactical choices are goals consumed by the same slewed controller.
	await _fixture(Vector3(0, 0, 300))
	enemy.ai.set_physics_process(true)
	enemy.ai.defensive_clock = 0
	var forward_before: Vector3 = -enemy.global_basis.z
	await _frames(2)
	_check(enemy.ai.mode == "EVADE" and enemy.ai.tactic.begins_with("BREAK") and enemy.ai.break_point.y < enemy.global_position.y, "Tail attacker triggers a shallow descending defensive break")
	_check(forward_before.angle_to(-enemy.global_basis.z) < 0.01 and absf(enemy.pilot.roll) <= enemy.ai.command_slew_rate * 2 / 120 + 0.001, "Break requests limited ordinary controls, with no instant aircraft rotation")
	var side: float = enemy.ai.last_break_side
	enemy.ai.break_timer = 0
	enemy.ai.defensive_clock = 0
	enemy.ai._begin_evade(true)
	_check(enemy.ai.last_break_side == -side, "Repeated centred tail threats request alternating scissors-like breaks")
	await _fixture(Vector3(0, 0, 300), false)
	enemy.ai.set_physics_process(true)
	enemy.rear_gunner.enabled = false
	enemy.guns.rounds_per_second = 0
	var start: Vector3 = enemy.global_position
	var initial_forward: Vector3 = -enemy.global_basis.z
	var lowest: float = INF
	var largest_rotation: float = 0
	var previous_forward: Vector3 = initial_forward
	var largest_input_change: float = 0
	var previous_roll: float = enemy.pilot.roll
	for tick in range(1800):
		await physics_frame
		if not is_instance_valid(enemy):
			break
		lowest = minf(lowest, enemy.altitude)
		largest_rotation = maxf(largest_rotation, previous_forward.angle_to(-enemy.global_basis.z))
		largest_input_change = maxf(largest_input_change, absf(enemy.pilot.roll - previous_roll))
		previous_forward = -enemy.global_basis.z
		previous_roll = enemy.pilot.roll
	_check(is_instance_valid(enemy) and not enemy.is_destroyed and lowest > 60 and enemy.global_position.distance_to(start) > 300 and initial_forward.angle_to(-enemy.global_basis.z) > 0.3, "Defensive break turns real velocity continuously while protecting altitude")
	_check(largest_rotation < 0.01 and largest_input_change <= enemy.ai.command_slew_rate / 120 + 0.001, "Live tactical manoeuvres retain angular and control slew limits")

	await _fixture(Vector3(0, 0, -250), false)
	enemy.ai.evade_on_rear_threat = false
	enemy.pending_reset_velocity = Vector3(0, 0, -80)
	enemy.request_reset()
	enemy.pending_reset_pose = Transform3D(Basis.IDENTITY, Vector3(0, 200, 0))
	enemy.pending_reset_velocity = Vector3(0, 0, -80)
	await _frames(5)
	enemy.ai.set_physics_process(false)
	var point: Vector3 = enemy.ai._pursuit_point()
	_check(enemy.ai.tactic == "HIGH YO-YO" and point.y > player.global_position.y, "Excess close-range closure requests a climbing yo-yo to avoid overshoot")
	await _fixture(Vector3(250, 0, -500), false)
	player.request_reset()
	player.pending_reset_pose = Transform3D(Basis.IDENTITY, Vector3(250, 200, -500))
	player.pending_reset_velocity = Vector3(0, 0, -80)
	await _frames(5)
	enemy = world.enemy
	enemy.ai.set_physics_process(false)
	enemy.request_reset()
	enemy.pending_reset_pose = Transform3D(Basis.IDENTITY, Vector3(0, 200, 0))
	enemy.pending_reset_velocity = Vector3(0, 0, -55)
	await _frames(5)
	enemy.ai.set_physics_process(false)
	point = enemy.ai._pursuit_point()
	_check(enemy.ai.tactic == "LOW YO-YO" and point.y < player.global_position.y, "Turning pursuit of a faster target requests a shallow speed-building descent")
	print("REAR GUNNER RESULT: ", checks - failures, "/", checks, " passed; ", failures, " failed")
	quit(1 if failures else 0)

func _fixture(local_target: Vector3, static_fixture: bool = true, basis: Basis = Basis.IDENTITY) -> void:
	player.freeze = false
	player.request_reset()
	player.pending_reset_pose = Transform3D(basis, Vector3(0, 200, 0) + basis * local_target)
	player.pending_reset_velocity = Vector3.ZERO if static_fixture else basis * Vector3(0, 0, -55)
	await _frames(6)
	enemy = world.enemy
	enemy.ai.combat_enabled = false
	enemy.request_reset()
	enemy.pending_reset_pose = Transform3D(basis, Vector3(0, 200, 0))
	enemy.pending_reset_velocity = Vector3.ZERO if static_fixture else basis * Vector3(0, 0, -55)
	await _frames(6)
	enemy.ai.set_physics_process(false)
	enemy.pilot.reset_commands()
	enemy.ai.combat_enabled = true
	enemy.ai.detection_range = 3200
	enemy.ai.pursuit_release_range = 7500
	enemy.ai.evade_on_rear_threat = true
	enemy.guns.rounds_per_second = 6
	enemy.ai.grace_period = 0
	enemy.ai.combat_unlocked = true
	enemy.rear_gunner.enabled = true
	enemy.rear_gunner.engagement_range = 500
	enemy.rear_gunner.aim_error_degrees = 0
	enemy.rear_gunner.spread_degrees = 0
	enemy.rear_gunner.reset()
	player.freeze = static_fixture
	enemy.freeze = static_fixture
	player.pilot.automated = true

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
