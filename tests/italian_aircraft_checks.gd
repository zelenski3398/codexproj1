extends SceneTree
var checks: int = 0
var failures: int = 0
var session: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	session = preload("res://main.tscn").instantiate()
	root.add_child(session)
	await _frames(3)
	session.start_flight("spitfire")
	await _frames(5)
	session.encounters.clear()
	session.enemy = null
	var aircraft: Array[EnemyAircraft] = []
	for i in range(3):
		var kind: String = ["cr42", "c200", "sm79"][i]
		var foe: EnemyAircraft = session.create_encounter_enemy(Vector3(-2500 + i * 2200, 800, -3500), false, kind)
		foe.ai.combat_enabled = false
		foe.ai.patrol_center = foe.reset_position
		aircraft.append(foe)
	await _frames(4)
	for foe in aircraft:
		var def: EnemyAircraftDefinition = (foe as ItalianEnemy).definition
		_check(foe.model is ItalianAircraftModel and foe.aircraft_kind == def.id and foe.marker_name == def.marker, def.id + " factory uses its own visual/identity")
		_check(foe.mass == def.mass_kg and foe.wing_area == def.wing_area and foe.engine_thrust == def.thrust and foe.health.hp == def.maximum_hp, def.id + " uses configured flight/health")
		_check(foe.components.definitions.size() == 8 and foe.components.profile == def.damage, def.id + " reuses eight component damage sensors")
		_check(foe.guns.pool != null and foe.collision_layer == 4 and foe.team_id == CombatTeams.ENEMY, def.id + " retains shared swept projectiles and enemy team")
		if def.bomber:
			_check((foe.model as ItalianAircraftModel).propellers.size() == 3 and (foe as ItalianEnemy).additional_gunners.size() == 1 and foe.guns.rounds_per_second == 0, "SM79 has three engines, dorsal/ventral mounts and route-first forward fire disabled")
		else:
			_check(foe.model.gun_ports.size() == 2 and not foe.rear_gunner.enabled, def.id + " has two forward guns and no fictitious rear gunner")
	var previous: Array[Vector3] = []
	var travelled: Array[float] = [0.0, 0.0, 0.0]
	for foe in aircraft:
		previous.append(foe.global_position)
	for tick in range(7200):
		await physics_frame
		if tick % 120 == 0:
			for i in range(3):
				travelled[i] += aircraft[i].global_position.distance_to(previous[i])
				previous[i] = aircraft[i].global_position
	for foe in aircraft:
		print("Italian patrol ", foe.aircraft_kind, " position=", foe.global_position, " airspeed=", foe.airspeed, " altitude=", foe.altitude)
		_check(not foe.is_destroyed and foe.airspeed > 35 and foe.altitude > 100 and travelled[aircraft.find(foe)] > 1500, foe.aircraft_kind + " flies a 60-second real-force patrol with terrain clearance")
	# Elevate the frozen player fixture so rear-to-front rounds cannot start
	# below the runway behind a pitched taildragger. Terrain blocking is correct.
	session.aircraft.freeze = true
	session.aircraft.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 300, 650))
	# Freeze precision fixtures AFTER live navigation, preserving shared swept hit code.
	for foe in aircraft:
		foe.freeze = true
		foe.ai.set_physics_process(false)
		foe.rear_gunner.enabled = false
		foe.rear_gunner.cease_fire()
		for g in (foe as ItalianEnemy).additional_gunners:
			g.enabled = false
			g.cease_fire()
	await _frames(2)
	for foe in aircraft:
		var hp: float = foe.health.hp
		var engine: DamageHitboxSpec = foe.components.definitions[&"engine"].hitboxes[0]
		var start: Vector3 = foe.to_global(engine.position + Vector3(0, 0, -30))
		session.aircraft.guns.pool.spawn(start, foe.global_basis.z * 12000, 1, 8, session.aircraft.get_rid(), true, CombatTeams.PLAYER)
		await _frames(3)
		_check(foe.health.hp < hp and foe.components.last_hit == &"engine" and foe.components.power_factor() < 1, foe.aircraft_kind + " swept player round strikes its fitted engine sensor and reduces power")
		foe.health.set_hp(50)
		_check(not foe.damage_effects.emitting, foe.aircraft_kind + " retains exact 50 HP smoke threshold")
		foe.health.set_hp(49)
		await _frames(30)
		_check(foe.damage_effects.emitting and foe.damage_effects.active_count() > 0, foe.aircraft_kind + " uses existing world-space smoke/fire")
		var before: float = session.aircraft.health.hp
		var sensor: DamageHitboxSpec = session.aircraft.components.definitions[&"fuselage"].hitboxes[0]
		var origin: Vector3 = session.aircraft.to_global(sensor.position + Vector3(0, 0, 20))
		foe.guns.pool.spawn(origin, -session.aircraft.global_basis.z * 12000, 1, 5, foe.get_rid(), true, CombatTeams.ENEMY)
		await _frames(3)
		_check(session.aircraft.health.hp < before, foe.aircraft_kind + " enemy rounds use the same damage path against player")
		var count: Array[int] = [0]
		foe.destroyed.connect(func(): count[0] += 1)
		foe.take_damage(200)
		foe.take_damage(200)
		_check(foe.is_destroyed and count[0] == 1 and not foe.ai.is_physics_processing() and not foe.rear_gunner.is_physics_processing(), foe.aircraft_kind + " destruction latches and stops controls/guns")
	_check((aircraft[0] as ItalianEnemy).definition.cruise_speed < (aircraft[1] as ItalianEnemy).definition.cruise_speed and (aircraft[0] as ItalianEnemy).definition.maximum_bank > (aircraft[1] as ItalianEnemy).definition.maximum_bank, "CR42 tuning is slower and more manoeuvrable than C200")
	session.queue_free()
	await _frames(3)
	print("ITALIAN AIRCRAFT CHECKS: ", checks, " checks; ", failures, " failures")
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
