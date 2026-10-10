extends SceneTree
## Production AI tuning plus real physics, swept projectiles and session lifecycle.
## Scenario transforms are supplied only through the aircraft's physics reset.
var world: Node3D
var player: FlightAircraft
var enemy: EnemyAircraft
var checks: int = 0
var failures: int = 0
var health_changes: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.start_flight("spitfire")
	player = world.aircraft
	enemy = world.enemy
	player.pilot.automated = true
	await _frames(6)
	_check(_enemy_count() == 1 and enemy.global_position.distance_to(player.global_position) > 700 and enemy.altitude > 120, "Exactly one enemy starts safely airborne, away from the runway player")
	_check(player.team_id == CombatTeams.PLAYER and enemy.team_id == CombatTeams.ENEMY and enemy.health.hp == 100, "Separate teams use shared 100-HP health and weapons")
	_check(enemy.ai.aim_error_degrees > 0 and enemy.guns.spread_degrees > 0 and enemy.ai.burst_rest > enemy.ai.burst_duration, "Production difficulty includes imperfect aim and pauses between short bursts")
	# Received damage triggers a bounded evasive manoeuvre, not an instant turn.
	var basis_before: Basis = enemy.global_basis
	var position_before: Vector3 = enemy.global_position
	enemy.take_damage(10)
	await _frames(3)
	_check(enemy.ai.mode == "EVADE" and enemy.ai.break_timer > 0 and not enemy.pilot.fire, "Surviving damage enters evade and inhibits firing")
	_check(enemy.global_position.distance_to(position_before) < 3 and basis_before.z.angle_to(enemy.global_basis.z) < 0.03 and absf(enemy.pilot.roll) < 0.1, "Evade begins smoothly through limited commands and physical motion")
	await _frames(480)
	_check(enemy.ai.mode == "PATROL" and enemy.ai.break_timer == 0 and not enemy.is_destroyed, "Evade expires and the aircraft resumes continuous patrol")

	# Swept collision and explicit team filtering operate in the live world.
	var friendly: FlightAircraft = FlightAircraft.new()
	friendly.reset_position = Vector3(1000, 180, 0)
	friendly.team_id = CombatTeams.ENEMY
	world.add_child(friendly)
	friendly.freeze = true
	friendly.collision_layer = 4
	friendly.collision_mask = 0
	await _frames(3)
	var shot: Vector3 = friendly.global_position + Vector3(0, 0, 20)
	enemy.guns.pool.spawn(shot, Vector3(0, 0, -30000), 0.03, 10, enemy.get_rid(), true, enemy.team_id)
	await _frames(4)
	_check(friendly.health.hp == 100 and enemy.guns.pool.total_hits > 0, "Enemy-team bullets stop at friendly aircraft without damaging them")
	friendly.team_id = CombatTeams.PLAYER
	player.guns.pool.spawn(shot, Vector3(0, 0, -30000), 0.03, 10, player.get_rid(), true, player.team_id)
	await _frames(4)
	_check(friendly.health.hp == 100, "Player-team bullets also prevent friendly fire")
	enemy.guns.pool.spawn(shot, Vector3(0, 0, -30000), 0.03, 10, enemy.get_rid(), true, enemy.team_id)
	await _frames(4)
	_check(friendly.health.hp == 90, "A fast opposing-team bullet sweeps through and damages an aircraft")
	friendly.team_id = CombatTeams.ENEMY
	var blocker: StaticBody3D = _blocker(Vector3(60, 60, 1), friendly.global_position + Vector3(0, 0, 10))
	await _frames(3) # Let the physics server register the new collider/transform.
	player.guns.pool.spawn(shot, Vector3(0, 0, -30000), 0.03, 20, player.get_rid(), true, player.team_id)
	await _frames(4)
	_check(friendly.health.hp == 90 and player.guns.pool.active.is_empty(), "Terrain-layer cover intercepts fast player gunfire before the target")
	friendly.team_id = CombatTeams.PLAYER
	enemy.guns.pool.spawn(shot, Vector3(0, 0, -30000), 0.03, 20, enemy.get_rid(), true, enemy.team_id)
	await _frames(4)
	_check(friendly.health.hp == 90 and enemy.guns.pool.active.is_empty(), "Terrain-layer cover also intercepts enemy gunfire")
	blocker.queue_free()
	friendly.queue_free()
	await _frames(3)
	var hits: int = enemy.guns.pool.total_hits
	var hp: float = enemy.health.hp
	enemy.guns.pool.spawn(enemy.global_position + Vector3(0, 0, 20), Vector3(0, 0, -30000), 0.02, 100, enemy.get_rid(), true, enemy.team_id)
	await _frames(4)
	_check(enemy.health.hp == hp and enemy.guns.pool.total_hits == hits, "Enemy rounds exclude their own body even when fired across its collider")
	hits = player.guns.pool.total_hits
	player.guns.pool.spawn(player.global_position + Vector3(0, 0, 20), Vector3(0, 0, -30000), 0.02, 100, player.get_rid(), true, player.team_id)
	await _frames(4)
	_check(player.health.hp == 100 and player.guns.pool.total_hits == hits, "Player rounds exclude their own airframe too")

	# Forecast altitude loss over actual rolling terrain, then physically recover.
	await _fresh()
	enemy.ai.combat_enabled = false
	var terrain_start: Vector3 = Vector3(1300, Airfield.height_at(1300, 0) + 75, 0)
	await _enemy_fixture(terrain_start, Vector3(0, -8, -58))
	await _frames(4)
	_check(enemy.ai.terrain_avoiding and enemy.ai.mode == "EVADE" and enemy.ai.avoidance_point.y > enemy.global_position.y and not enemy.pilot.fire, "Look-ahead detects dangerous descent over hills and requests a climb")
	var minimum: float = INF
	var max_rotation_step: float = 0
	var max_move_step: float = 0
	var previous_position: Vector3 = enemy.global_position
	var previous_forward: Vector3 = -enemy.global_basis.z
	var pitch_command: float = enemy.pilot.pitch
	var largest_command_step: float = 0
	for tick in range(1440):
		await physics_frame
		minimum = minf(minimum, enemy.altitude)
		max_rotation_step = maxf(max_rotation_step, previous_forward.angle_to(-enemy.global_basis.z))
		max_move_step = maxf(max_move_step, previous_position.distance_to(enemy.global_position))
		largest_command_step = maxf(largest_command_step, absf(enemy.pilot.pitch - pitch_command))
		pitch_command = enemy.pilot.pitch
		previous_position = enemy.global_position
		previous_forward = -enemy.global_basis.z
	print("Hill clearance=", minimum, " rotation step=", max_rotation_step, " displacement step=", max_move_step)
	_check(not enemy.is_destroyed and minimum > 45 and enemy.global_position.y > terrain_start.y, "Real flight forces recover the descending enemy without touching terrain")
	_check(max_rotation_step < 0.01 and max_move_step < 1 and largest_command_step <= enemy.ai.command_slew_rate / 120.0 + 0.001, "Navigation has bounded turn/movement and slewed commands, with no teleporting")

	# A tall obstacle ahead exercises sideways avoidance rather than terrain-only
	# altitude checking. The AI must maintain a physical gap while turning.
	await _enemy_fixture(Vector3(1500, 160, 500), Vector3(0, 0, -58))
	blocker = _blocker(Vector3(60, 400, 25), Vector3(1500, 180, 240))
	await _frames(3)
	enemy.ai.scan_clock = 0
	await _frames(4)
	_check(enemy.ai.mode == "EVADE" and absf(enemy.ai.avoidance_point.x - enemy.global_position.x) > 100, "Forward obstacle probes choose a sideways evasive route")
	var obstacle_clearance: float = INF
	for tick in range(840):
		await physics_frame
		obstacle_clearance = minf(obstacle_clearance, enemy.global_position.distance_to(Vector3(1500, enemy.global_position.y, 240)))
	_check(not enemy.is_destroyed and obstacle_clearance > 40, "Enemy physically steers around a tall obstacle without crossing its collider")
	blocker.queue_free()
	await _frames(3)
	await _enemy_fixture(Vector3(4600, 180, 0), Vector3(58, 0, 0), Basis(Vector3.UP, -PI / 2))
	await _frames(4)
	_check(enemy.ai.mode == "EVADE" and enemy.ai.avoidance_point.x < 100, "Enemy turns back before leaving the finite countryside")

	# Production aim remains bounded yet really damages a moving player.
	await _fresh()
	player.request_reset()
	player.pending_reset_pose = Transform3D(Basis.IDENTITY, Vector3(0, 150, 200))
	player.pending_reset_velocity = Vector3(0, 0, -55)
	await _frames(6)
	enemy = world.enemy
	player.gear.extended = false
	player.pilot.throttle = 0.7
	enemy.ai.combat_enabled = true
	enemy.ai.grace_period = 0
	await _enemy_fixture(Vector3(0, 150, 500), Vector3(0, 0, -55))
	await _frames(20)
	_check(enemy.ai.mode == "ENGAGE" and enemy.ai.aim_bias.length() > 0 and absf(enemy.ai.aim_bias.x) <= enemy.ai.aim_error_degrees and absf(enemy.ai.aim_bias.y) <= enemy.ai.aim_error_degrees, "Lead aiming receives a configurable, bounded nonzero error per burst")
	for tick in range(700):
		player.pilot.pitch = clampf((0.02 - player.rotation.x) * 4, -0.5, 0.5)
		await physics_frame
	_check(player.health.hp < 100 and enemy.guns.pool.total_hits > 0 and enemy.health.hp == 100, "Imperfect production AI still hits the moving player without self-damage")

	# Enemy health uses the same strict threshold and world-space effect pool.
	await _fresh()
	enemy.ai.combat_enabled = false
	enemy.take_damage(50)
	await _frames(10)
	_check(enemy.health.hp == 50 and not enemy.damage_effects.emitting and enemy.damage_effects.active_count() == 0, "Exactly 50 enemy HP leaves smoke and fire off")
	enemy.take_damage(1)
	await _frames(120)
	var smoke_index: int = -1
	var flames: int = 0
	for i in range(enemy.damage_effects.particles.size()):
		if enemy.damage_effects.particles[i].visible:
			if enemy.damage_effects.is_smoke[i]:
				smoke_index = i
			else:
				flames += 1
	_check(enemy.health.hp == 49 and enemy.damage_effects.emitting and smoke_index >= 0 and flames > 0, "49 enemy HP activates both engine smoke and fire")
	var trail_position: Vector3 = enemy.damage_effects.particles[smoke_index].global_position if smoke_index >= 0 else Vector3.ZERO
	var trail_velocity: Vector3 = enemy.damage_effects.velocities[smoke_index] if smoke_index >= 0 else Vector3.ZERO
	await _frames(12)
	_check(smoke_index >= 0 and enemy.damage_effects.particles[smoke_index].global_position.distance_to(trail_position) < 3 and trail_velocity.length() < enemy.linear_velocity.length() * 0.3, "Smoke lingers in world space while the moving Stuka pulls away")
	var intensity: float = enemy.damage_effects.intensity
	enemy.take_damage(30)
	await _frames(10)
	_check(enemy.damage_effects.intensity > intensity, "Enemy damage effects intensify as HP decreases")
	enemy.health.heal(31)
	await _frames(320)
	_check(enemy.health.hp == 50 and not enemy.damage_effects.emitting and enemy.damage_effects.active_count() == 0, "Healing to 50 stops emission and existing smoke fades")

	# Health widgets use camera projection, range and visibility, not billboards
	# that remain visible behind the player or across the entire map.
	await _fresh()
	enemy.ai.combat_enabled = false
	await _enemy_fixture(Vector3(0, 70, 450), Vector3(0, 0, -58))
	world.chase.snap()
	await process_frame
	world.hud._update_enemy(world.chase)
	_check(world.hud.enemy_health_widget.visible and world.hud.enemy_hp_bar.value == 100 and world.hud.enemy_hp_label.text.contains("100/100"), "Nearby enemy displays an overhead health bar and numeric HP")
	enemy.take_damage(25)
	world.hud._update_enemy(world.chase)
	_check(world.hud.enemy_hp_bar.value == 75 and world.hud.enemy_hp_label.text.contains("75/100"), "Enemy overhead bar tracks damage")
	await _enemy_fixture(Vector3(0, 60, 900), Vector3(0, 0, -58))
	world.hud._update_enemy(world.chase)
	_check(not world.hud.enemy_health_widget.visible, "Enemy health bar hides behind the camera")
	await _enemy_fixture(Vector3(0, 150, -700), Vector3(0, 0, -58))
	world.hud._update_enemy(world.chase)
	_check(not world.hud.enemy_health_widget.visible, "Enemy health bar hides beyond its configured nearby range")

	# A real player projectile delivers the fatal hit; further hits do nothing.
	await _fresh()
	enemy.ai.combat_enabled = false
	await _enemy_fixture(Vector3(0, 30, 0), Vector3(0, -8, -40))
	enemy.health.changed.connect(func(_hp: float, _maximum: float): health_changes += 1)
	player.guns.pool.spawn(enemy.global_position + Vector3(0, 0, 20), Vector3(0, 0, -30000), 0.03, 100, player.get_rid(), true, player.team_id)
	await _frames(4)
	_check(enemy.is_destroyed and enemy.health.hp == 0 and enemy.ai.mode == "DESTROYED" and not enemy.ai.is_physics_processing() and not enemy.pilot.fire and enemy.pilot.throttle == 0, "Fatal player hit stops enemy AI, guns and thrust once")
	enemy.take_damage(10)
	enemy.take_damage(100)
	_check(health_changes == 1 and world.defeat_notifications == 1 and world.enemy_defeated, "Destroyed enemy rejects repeated damage and emits one defeat notification")
	var wreck_y: float = enemy.global_position.y
	await _frames(60)
	_check(not enemy.freeze and enemy.global_position.y < wreck_y - 1 and not enemy.impact_started, "Airborne wreck falls under existing physics before ground impact")
	var wreck: EnemyAircraft = enemy
	for tick in range(1800):
		await physics_frame
		if wreck.impact_started:
			break
	await _frames(4)
	_check(wreck.impact_count == 1 and world.encounter_effects.get_child_count() == 1 and wreck.freeze, "First ground contact emits one brief destruction burst and settles the wreck")
	_check(not wreck.damage_effects.emitting and wreck.damage_effects.active_count() == 0, "Ground impact stops and clears the wreck's engine effects")
	wreck.take_damage(100)
	await _frames(60)
	_check(wreck.impact_count == 1 and world.defeat_notifications == 1 and world.encounter_effects.get_child_count() == 1, "Further impacts or damage cannot repeat explosions or kill notifications")
	await _frames(450)
	_check(not is_instance_valid(wreck) and world.enemy == null and _enemy_count() == 0 and world.encounter_effects.get_child_count() == 0, "Brief impact effect and wreck disappear after their configured delays")
	await process_frame
	_check(world.hud.notice_label.text.contains("Enemy destroyed") and world.hud.enemy_label.text.contains("ENEMY DESTROYED") and not world.hud.overlay.visible and not paused, "Enemy destroyed remains visible after cleanup while player flight continues")
	player.pilot.throttle = 0.7
	var player_start: Vector3 = player.global_position
	await _frames(120)
	_check(player.global_position.distance_to(player_start) > 1 and player.health.hp == 100, "Player can accelerate and continue flying after the opponent is removed")
	_key(KEY_R, true)
	_key(KEY_R, false)
	await _frames(6)
	enemy = world.enemy
	_check(_enemy_count() == 1 and enemy.health.hp == 100 and not enemy.is_destroyed and enemy.ai.mode == "PATROL" and enemy.ai.airborne_timer == 0, "Actual R spawns exactly one fresh airborne enemy after wreck cleanup")
	_check(player.health.hp == 100 and player.pilot.throttle == 0 and not world.enemy_defeated and world.defeat_notifications == 0 and player.guns.pool.active.is_empty() and enemy.guns.pool.active.is_empty(), "Session restart clears defeat state and rounds and restores the player")

	# Restart during an active burst/wreck must also leave no orphan effects.
	enemy.ai.aim_error_degrees = 0.32
	await _enemy_fixture(Vector3(0, 1.5, 0), Vector3(0, -10, -35))
	enemy.take_damage(100)
	for tick in range(120):
		await physics_frame
		if enemy.impact_started:
			break
	await _frames(3)
	_check(world.encounter_effects.get_child_count() == 1, "Mid-destruction restart fixture has an active world-space impact burst")
	var old_enemy_id: int = enemy.get_instance_id()
	player.take_damage(60)
	await _frames(20)
	player.guns.pool.spawn(Vector3(0, 100, 0), Vector3(0, 0, -10), 2, 1, player.get_rid(), true, player.team_id)
	enemy.guns.pool.spawn(Vector3(100, 100, 0), Vector3(0, 0, -10), 2, 1, enemy.get_rid(), true, enemy.team_id)
	_key(KEY_R, true)
	_key(KEY_R, false)
	await _frames(6)
	enemy = world.enemy
	_check(enemy.get_instance_id() != old_enemy_id and _enemy_count() == 1 and world.encounter_effects.get_child_count() == 0, "Restart replaces the old wreck with one new instance and clears impact effects")
	_check(player.health.hp == 100 and player.damage_effects.active_count() == 0 and enemy.damage_effects.active_count() == 0 and enemy.guns.pool.active.is_empty() and player.guns.pool.active.is_empty(), "Restart clears both bullet pools and every aircraft smoke/fire trail")
	_check(enemy.ai.aim_error_degrees == 0.32 and not enemy.ai.combat_enabled, "Fresh sessions preserve configurable difficulty settings")
	for press in range(3):
		_key(KEY_R, true)
		_key(KEY_R, false)
	await _frames(6)
	_check(_enemy_count() == 1 and world.encounter_effects.get_child_count() == 0 and not world.enemy_defeated, "Repeated reset input cannot duplicate enemies or resurrect old effects")
	print("ENCOUNTER RESULT: ", checks - failures, "/", checks, " passed; ", failures, " failed")
	quit(1 if failures else 0)

func _fresh() -> void:
	player.request_reset()
	await _frames(6)
	enemy = world.enemy

func _enemy_fixture(position: Vector3, velocity: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	enemy.request_reset()
	enemy.pending_reset_pose = Transform3D(basis, position)
	enemy.pending_reset_velocity = velocity
	await _frames(6)

func _blocker(size: Vector3, position: Vector3) -> StaticBody3D:
	var blocker: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	collision.shape = box
	blocker.add_child(collision)
	world.add_child(blocker)
	blocker.global_position = position
	return blocker

func _enemy_count() -> int:
	var count: int = 0
	for node in world.get_children():
		if node is EnemyAircraft:
			count += 1
	return count

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
