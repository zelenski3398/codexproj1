extends SceneTree
## Production escort/gunner settings, moving player fixture flown with controls.
var session: Node3D
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	session = preload("res://main.tscn").instantiate()
	root.add_child(session)
	session.start_interception("spitfire")
	await _frames(180)
	session.malta_mission.board_nearest()
	session.interception.activate()
	await _frames(4)
	var encounter: VallettaInterception = session.interception
	var player: FlightAircraft = session.aircraft
	var escort: EnemyAircraft = encounter.escort
	var direction: Vector3 = encounter.definition.approach_direction.normalized()
	var start: Vector3 = escort.global_position + direction * 490
	player.request_reset()
	player.pending_reset_pose = Transform3D(Basis.looking_at(direction, Vector3.UP), start)
	player.pending_reset_velocity = direction * 68
	await _frames(3)
	player.pilot.automated = true
	player.engine_running = true
	player.gear.extended = false
	var steering: EnemyPilot = EnemyPilot.new()
	steering.aircraft = player
	steering.measured_terrain = true
	steering.cruise_speed = 68
	var engaged: bool = false
	var fired: bool = false
	for tick in range(4200):
		steering._fly_toward(player.global_position + direction * 1500 + Vector3.UP * (start.y - player.global_position.y), 1.0 / 120)
		await physics_frame
		engaged = engaged or escort.ai.mode == "ENGAGE"
		fired = fired or escort.pilot.fire
		if player.health.hp < 95:
			break
	print("Escort engagement mode=", escort.ai.mode, " shots=", escort.guns.pool.statistics.shots, " hits=", escort.guns.pool.statistics.aircraft_hits, " playerHP=", player.health.hp)
	_check(engaged and fired and escort.guns.pool.statistics.shots > 0, "C200 mission escort leaves formation and fires real bursts at an airborne threat")
	_check(player.health.hp < 100, "Production C200 pursuit/lead produces real swept projectile damage")
	# Outside the mission leash the same controller returns physically, no teleport.
	escort.ai.mission_leash = 100
	var old_position: Vector3 = escort.global_position
	await _frames(30)
	_check(escort.ai.tactic == "RETURN TO FORMATION" and not escort.pilot.fire and escort.global_position.distance_to(old_position) < 35, "Escort beyond mission leash returns through normal slewed controls")
	steering.free()
	# Isolate dorsal defensive fire from escort, using its original human skill.
	session.restart_malta()
	await _frames(180)
	session.malta_mission.board_nearest()
	session.interception.activate()
	await _frames(4)
	encounter = session.interception
	player = session.aircraft
	encounter.escort.ai.combat_enabled = false
	var bomber: EnemyAircraft = encounter.bomber
	player.request_reset()
	var behind: Vector3 = bomber.to_global(Vector3(-100, 100, 240))
	player.pending_reset_pose = Transform3D(bomber.global_basis, behind)
	player.pending_reset_velocity = bomber.linear_velocity
	await _frames(3)
	player.pilot.automated = true
	player.engine_running = true
	player.gear.extended = false
	steering = EnemyPilot.new()
	steering.aircraft = player
	steering.measured_terrain = true
	steering.cruise_speed = 65
	var defensive_shots: bool = false
	for tick in range(3600):
		var goal: Vector3 = bomber.to_global(Vector3(-100, 100, -1800))
		steering._fly_toward(goal, 1.0 / 120)
		await physics_frame
		defensive_shots = defensive_shots or bomber.rear_gunner.guns.pool.statistics.shots > 0
		if defensive_shots and player.health.hp < 100:
			break
	print("Bomber defense status=", bomber.rear_gunner.status, " shots=", bomber.rear_gunner.guns.pool.statistics.shots, " playerHP=", player.health.hp)
	_check(player.health.hp < 100, "SM79 human defensive gunner damages the moving player through shared swept hits")
	_check(defensive_shots, "SM79 dorsal position uses the human gunner's limited tracking/bursts and real projectiles")
	_check(not bomber.rear_gunner.shot_has_clearance(bomber.rear_gunner.muzzle().global_position, (bomber.global_position - bomber.rear_gunner.muzzle().global_position).normalized()), "Bomber gunner rejects dispersed shots directed into its own airframe")
	_check(bomber.ai is BomberPilot and (bomber.ai as BomberPilot).assigned_route and not bomber.is_destroyed, "Defensive shooting preserves assigned physical bombing route")
	steering.free()
	session.queue_free()
	await _frames(3)
	print("INTERCEPTION COMBAT CHECKS: ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)
func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
