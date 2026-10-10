extends SceneTree
## Live rigid-body AI and shared-projectile integration; no scripted flight motion.
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
	enemy = world.enemy
	player.pilot.automated = true
	await _frames(5)
	_check(enemy.model is StukaModel and enemy.model.gun_ports.size() == 2 and player.model.gun_ports.size() == 8, "Reference-inspired enemy has two wing guns; Spitfire retains eight")
	_check(enemy.health.hp == 100 and enemy.pilot.automated and enemy.collision_layer == 4, "Enemy uses separate AI, health and projectile collision layer")
	_check(world.get_node_or_null("PracticeTarget") == null, "Flying enemy replaces the stationary gameplay target")
	var start: Vector3 = enemy.global_position
	var heading: Vector3 = -enemy.global_basis.z
	var minimum_altitude: float = INF
	for tick in range(10800):
		await physics_frame
		minimum_altitude = minf(minimum_altitude, enemy.altitude)
		if tick % 1200 == 0:
			print("Patrol t=", tick / 120.0, " pos=", enemy.global_position, " speed=", enemy.airspeed, " bank=", enemy.global_basis.x.y, " mode=", enemy.ai.mode)
	_check(not enemy.is_crashed and not enemy.is_destroyed and minimum_altitude > 90 and enemy.airspeed > 40, "AI patrols for 90 simulated seconds without stalling or hitting terrain")
	_check(enemy.global_position.distance_to(start) > 100 and heading.angle_to(-enemy.global_basis.z) > 0.3 and absf(enemy.linear_velocity.x) > 1, "Patrol banks and turns real velocity through aerodynamic forces")
	_check(player.health.hp == 100 and enemy.guns.pool.total_spawned == 0 and enemy.ai.mode == "PATROL", "Enemy never shoots the parked player")
	# A full encounter from patrol must acquire the player and survive pursuit,
	# not merely succeed when a test begins with the guns already aligned.
	player.request_reset()
	player.pending_reset_pose = Transform3D(Basis.IDENTITY, Vector3(0, 160, 300))
	player.pending_reset_velocity = Vector3(0, 0, -58)
	await _frames(6)
	enemy = world.enemy
	player.gear.extended = false
	player.pilot.throttle = 0.6
	var acquired: bool = false
	var attacked: bool = false
	var pursuit_altitude: float = INF
	for tick in range(9000):
		# Test-only healing keeps the flight trial running after successful hits.
		player.health.heal(100)
		player.pilot.throttle = clampf(0.33 + (58 - player.airspeed) * 0.03, 0, 1)
		player.pilot.pitch = clampf((0.02 + (160 - player.global_position.y) * 0.008 - player.rotation.x) * 4, -0.7, 0.7)
		await physics_frame
		acquired = acquired or enemy.ai.mode == "ENGAGE"
		attacked = attacked or enemy.pilot.fire
		pursuit_altitude = minf(pursuit_altitude, enemy.altitude)
		if tick % 1200 == 0:
			print("Pursuit t=", tick / 120.0, " mode=", enemy.ai.mode, " distance=", enemy.global_position.distance_to(player.global_position), " aimAngle=", rad_to_deg((-enemy.global_basis.z).angle_to((enemy.ai._lead_point() - enemy.global_position).normalized())), " playerSpeed=", player.airspeed, " enemySpeed=", enemy.airspeed, " hits=", enemy.guns.pool.total_hits)
	print("Acquire=", acquired, " attack=", attacked, " hits=", enemy.guns.pool.total_hits)
	_check(acquired and attacked and enemy.guns.pool.total_hits > 0, "Enemy acquires and attacks the player starting from its ordinary patrol")
	_check(not enemy.is_crashed and pursuit_altitude > 40 and enemy.airspeed > 35, "Pursuit controller survives a 75-second live airborne encounter")
	# Deterministic precision fixtures isolate rate/damage/reset from aim randomness
	# and evasive response. encounter_checks separately exercises production tuning.
	enemy.ai.aim_error_degrees = 0
	enemy.guns.spread_degrees = 0
	enemy.ai.evade_on_damage = false
	# Both aircraft fly forward at equal speed: the AI must really lead and hit.
	await _fixture(Vector3(0, 150, 200), Vector3(0, 150, 500), 55)
	enemy.ai.grace_period = 0
	var previous_hp: float = player.health.hp
	for tick in range(720):
		player.pilot.pitch = clampf((0.02 - player.rotation.x) * 4, -0.5, 0.5)
		await physics_frame
	print("Combat playerHP=", player.health.hp, " shots=", enemy.guns.pool.total_spawned, " hits=", enemy.guns.pool.total_hits, " mode=", enemy.ai.mode, " distance=", player.global_position.distance_to(enemy.global_position))
	_check(enemy.guns.pool.total_spawned > 0 and enemy.guns.pool.total_hits > 0 and player.health.hp < previous_hp, "AI pursuit and actual swept enemy rounds damage the moving player")
	_check(enemy.health.hp == 100, "Enemy rounds exclude their owner's RID")
	_check(player.health.hp < 50 and player.damage_effects.emitting, "Incoming gun damage activates engine smoke/fire below 50 HP")
	# Fire/rest cycles are measurable without replacing the real AI or guns.
	enemy.ai.grace_period = 8
	await _fixture(Vector3(0, 150, 200), Vector3(0, 150, 500), 55)
	var shots: int = enemy.guns.pool.total_spawned
	await _frames(840)
	_check(enemy.ai.mode == "PATROL" and enemy.guns.pool.total_spawned == shots and player.health.hp == 100, "Eight-second airborne grace period protects the initial climb")
	enemy.ai.grace_period = 0
	await _fixture(Vector3(0, 150, 200), Vector3(0, 150, 500), 55)
	shots = enemy.guns.pool.total_spawned
	enemy.ai.burst_clock = enemy.ai.burst_duration + 0.1
	await _frames(30)
	_check(enemy.ai.mode == "ENGAGE" and not enemy.pilot.fire and enemy.guns.pool.total_spawned == shots, "Aligned enemy rests between bursts instead of firing continuously")
	enemy.ai.burst_clock = 0
	await _frames(45)
	_check(enemy.pilot.fire and enemy.guns.pool.total_spawned > shots, "Enemy resumes a bounded two-gun burst")
	var position: Vector3 = enemy.global_position
	var clock: float = enemy.ai.burst_clock
	var rounds: int = enemy.guns.pool.total_spawned
	paused = true
	for tick in range(20):
		await process_frame
	_check(enemy.global_position.is_equal_approx(position) and enemy.ai.burst_clock == clock and enemy.guns.pool.total_spawned == rounds, "Pause freezes enemy physics, AI and weapons together")
	paused = false
	# Fresh airborne encounter, with the enemy in front of the player's guns.
	enemy.ai.combat_enabled = false
	await _fixture(Vector3(0, 150, 500), Vector3(0, 150, 250), 58)
	player.pilot.fire = true
	await _frames(120)
	player.pilot.fire = false
	print("Player fire enemyHP=", enemy.health.hp, " hits=", player.guns.pool.total_hits)
	_check(player.guns.pool.total_hits > 0 and enemy.health.hp < 100, "Player's eight guns hit and damage a physically flying enemy")
	for tick in range(240):
		if enemy.is_destroyed:
			break
		player.pilot.fire = true
		await physics_frame
	player.pilot.fire = false
	_check(enemy.is_destroyed and enemy.health.hp == 0 and enemy.ai.mode == "DESTROYED", "Actual player gunfire shoots the enemy down")
	enemy.wreck_remove_delay = 30.0 # Dedicated lifecycle suite tests default cleanup.
	var downed_y: float = enemy.global_position.y
	var enemy_rounds: int = enemy.guns.pool.total_spawned
	await _frames(1440)
	print("Wreck initialY=", downed_y, " currentY=", enemy.global_position.y, " velocity=", enemy.linear_velocity)
	_check(not enemy.freeze and enemy.global_position.y < downed_y - 1 and enemy.pilot.throttle == 0 and enemy.guns.pool.total_spawned == enemy_rounds, "Shot-down enemy falls using physics with engine and guns off")
	_check(world.hud.enemy_label.text.contains("ENEMY DESTROYED") and world.hud.notice_label.text.contains("Enemy destroyed"), "HUD reports a shot-down enemy without ending the player's flight")
	# Player reset is authoritative for both lives and all world-space effects.
	player.take_damage(70)
	await _frames(30)
	player.request_reset()
	await _frames(6)
	enemy = world.enemy
	_check(player.health.hp == 100 and enemy.health.hp == 100 and not player.is_destroyed and not enemy.is_destroyed and not enemy.is_crashed, "R-equivalent reset restores both aircraft and enemy AI")
	_check(player.guns.pool.active.is_empty() and enemy.guns.pool.active.is_empty() and player.damage_effects.active_count() == 0 and enemy.damage_effects.active_count() == 0, "Encounter reset clears both bullet pools and damage trails")
	_check(player.global_position.distance_to(player.reset_position) < 0.1 and player.pilot.throttle == 0 and enemy.global_position.y > 150 and enemy.linear_velocity.length() > 50, "Reset parks the player safely and restarts the enemy airborne")
	# Debug/player input must never leak into the AI's pilot or health.
	_key(KEY_H, true)
	_key(KEY_H, false)
	_key(KEY_G, true)
	_key(KEY_G, false)
	await _frames(3)
	_check(player.health.hp == 90 and enemy.health.hp == 100 and enemy.gear.extended, "H and G only affect the player; enemy fixed gear remains extended")
	_key(KEY_CTRL, true)
	player.pilot.automated = false
	await _frames(30)
	_key(KEY_CTRL, false)
	_check(player.guns.pool.active.size() > 0 and enemy.guns.pool.active.is_empty(), "Player Ctrl input cannot fire the enemy's guns")
	player.pilot.automated = true
	# Unarmed test fixture obstruction checks the AI's real physics LOS ray.
	await _fixture(Vector3(0, 150, 200), Vector3(0, 150, 500), 58)
	var blocker: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(60, 60, 5)
	shape.shape = box
	blocker.add_child(shape)
	world.add_child(blocker)
	blocker.global_position = Vector3(0, 150, 350)
	await _frames(3)
	_check(not enemy.ai._clear_line_of_sight(), "Terrain-layer obstacles block the enemy's firing line")
	blocker.queue_free()
	await _frames(3)
	_check(enemy.ai._clear_line_of_sight(), "Removing an obstacle restores line of sight to the player's collider")
	enemy.ai.combat_enabled = true
	enemy.ai.grace_period = 0
	await _fixture(Vector3(0, 150, 200), Vector3(0, 150, 260), 58)
	await _frames(10)
	_check(enemy.ai.mode == "EVADE" and not enemy.pilot.fire, "Close passes trigger a break-away turn instead of point-blank firing")
	await _fixture(Vector3(0, 150, 500), Vector3(0, 150, 200), 58)
	await _frames(10)
	_check(enemy.ai.mode == "EVADE" and enemy.ai.tactic.begins_with("BREAK") and not enemy.pilot.fire, "A rear attacker triggers a physical defensive break; forward guns cannot fire backwards")
	# Destruction of the player ends attacks and leaves a falling wreck.
	await _fixture(Vector3(0, 150, 200), Vector3(0, 150, 500), 55)
	for tick in range(2400):
		player.pilot.pitch = clampf((0.02 - player.rotation.x) * 4, -0.5, 0.5)
		await physics_frame
		if player.is_destroyed:
			break
	_check(player.is_destroyed and player.health.hp == 0, "Enemy bursts can destroy the player's aircraft through real projectile hits")
	await _frames(6)
	_check(enemy.ai.mode == "PATROL" and not enemy.pilot.fire and player.pilot.throttle == 0 and world.hud.overlay_title.text == "DESTROYED", "Enemy disengages after player destruction and HUD offers reset")
	_key(KEY_R, true)
	_key(KEY_R, false)
	await _frames(6)
	enemy = world.enemy
	_check(player.health.hp == 100 and enemy.health.hp == 100 and not player.is_destroyed and enemy.ai.airborne_timer == 0 and enemy.guns.pool.active.is_empty(), "Actual R key restores the encounter after hostile destruction")
	print("ENEMY RESULT: ", checks - failures, "/", checks, " passed; ", failures, " failed")
	quit(1 if failures else 0)

func _fixture(player_position: Vector3, enemy_position: Vector3, speed: float) -> void:
	var combat: bool = enemy.ai.combat_enabled
	enemy.ai.combat_enabled = false
	player.request_reset()
	player.pending_reset_pose = Transform3D(Basis.IDENTITY, player_position)
	player.pending_reset_velocity = Vector3(0, 0, -speed)
	await _frames(5)
	enemy = world.enemy
	player.gear.extended = false
	player.pilot.throttle = 0.7
	enemy.request_reset()
	enemy.pending_reset_pose = Transform3D(Basis.IDENTITY, enemy_position)
	enemy.pending_reset_velocity = Vector3(0, 0, -speed)
	await _frames(5)
	enemy.ai.combat_enabled = combat

func _frames(count: int) -> void:
	for tick in range(count):
		await physics_frame

func _key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
