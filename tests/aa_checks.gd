extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if value: passed += 1; print("PASS: ",message)
	else: failed += 1; push_error("FAIL: " + message)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await frames(8)
	scene.start_malta("ta_qali","spitfire","interception")
	await frames(12)
	var battery: AirfieldAABattery = scene.malta_mission.world.aa_battery
	check(battery.guns.size() == 6, "Exactly six AA guns in the continuous Malta world")
	check(battery.candidates().is_empty(), "Checkpoint phase has no premature mission enemies")
	for gun in battery.guns:
		check(gun.yaw != null and gun.elevation != null and gun.muzzle != null,gun.name + ": imported aiming hierarchy")
		var field: MaltaAirfield
		for candidate in scene.malta_mission.world.fields.values():
			if gun.name.begins_with(candidate.record.id): field = candidate
		var local := field.to_local(gun.global_position)
		check(local.x < -60 and absf(local.z) < field.runway_length * 0.4, gun.name + ": clear of runway/apron/parking")
		var ray := PhysicsRayQueryParameters3D.create(gun.global_position + Vector3.UP * 0.1,gun.global_position - Vector3.UP,1,[gun.get_rid()])
		check(not gun.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),gun.name + ": terrain-supported pad")
	var enemy := EnemyAircraft.new()
	enemy.team_id = CombatTeams.ENEMY
	enemy.target = scene.aircraft
	scene.add_child(enemy)
	enemy.freeze = true
	enemy.reset_pending = false
	enemy.global_position = battery.guns[0].global_position + Vector3(0,250,-400)
	await frames(4)
	check(battery.candidates().has(enemy),"Enemy faction acquired without selecting parked friendly planes")
	for gun in battery.guns:
		gun.target = enemy
		gun.reaction = 0
		gun.scan_time = 100
	await frames(360)
	var gun := battery.guns[0]
	check(gun.shots_fired > 0, "Imported pivots smoothly aim and fire visible swept shells")
	check((-gun.muzzle.global_basis.z).dot((enemy.global_position-gun.muzzle.global_position).normalized()) > 0.9,"Muzzle local -Z follows actual elevated barrel")
	var stress_targets: Array[EnemyAircraft] = []
	for i in range(1,6):
		var dummy := EnemyAircraft.new()
		dummy.target = scene.aircraft
		scene.add_child(dummy)
		dummy.freeze = true
		dummy.reset_pending = false
		dummy.global_position = battery.guns[i].global_position + Vector3(0,250,-400)
		stress_targets.append(dummy)
		battery.guns[i].target = dummy
		battery.guns[i].reaction = 0
		battery.guns[i].scan_time = 100
	await frames(360)
	check(battery.guns.all(func(g):return g.shots_fired > 0),"All six emplacements operate simultaneously")
	for dummy in stress_targets: dummy.queue_free()
	check(battery.projectiles.active.size() <= 96 and battery.effects.particles.size() == 192,"Six guns share bounded shell/effect pools")
	# Controlled direct shot through a real engine hitbox, using the shared pool.
	for other in battery.guns: other.set_physics_process(false)
	battery.projectiles.clear()
	var old_position := enemy.global_position
	enemy.queue_free()
	enemy = EnemyAircraft.new()
	enemy.team_id = CombatTeams.ENEMY
	enemy.target = scene.aircraft
	scene.add_child(enemy)
	enemy.freeze = true
	enemy.reset_pending = false
	enemy.global_position = old_position
	await frames(4)
	var box: AircraftHitbox = enemy.components.hitboxes[0]
	var center: Vector3 = box.get_child(0).global_position
	var before := enemy.health.hp
	battery.projectiles.spawn(center + Vector3(0,30,1),Vector3(0,-700,-23.333),1,12,gun.get_rid(),true,CombatTeams.PLAYER)
	await frames(8)
	check(enemy.health.hp < before,"AA swept direct hit damages existing aircraft components/HP")
	var hp := enemy.health.hp
	battery._burst(center,box,CombatTeams.PLAYER)
	check(enemy.health.hp == hp,"Direct victim excluded from same-impact blast damage")
	battery._burst(center + Vector3.UP * 3,null,CombatTeams.PLAYER)
	check(enemy.health.hp < hp,"Actual nearby burst applies limited component damage")
	var friendly: FlightAircraft = scene.aircraft
	var friendly_hp: float = friendly.health.hp
	battery._burst(friendly.global_position,null,CombatTeams.PLAYER)
	check(friendly.health.hp == friendly_hp,"Blast never damages British/player aircraft")
	check(not CombatTeams.can_damage(CombatTeams.PLAYER,gun) and CombatTeams.can_damage(CombatTeams.ENEMY,gun),"Emplacement team rejects friendly bullets and accepts enemy bullets")
	gun.target = enemy
	var blocker := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var geometry := BoxShape3D.new()
	geometry.size = Vector3(80,80,80)
	shape.shape = geometry
	blocker.add_child(shape)
	scene.add_child(blocker)
	blocker.global_position = (gun.muzzle.global_position + enemy.global_position) * 0.5
	await frames(3)
	check(not gun.clear_line(enemy.global_position),"Buildings/terrain collision obstructs firing line")
	blocker.queue_free()
	var receiver := battery.guns[1]
	var receiver_hp := receiver.hp
	battery.projectiles.spawn(receiver.global_position + Vector3(0,1,15),Vector3(0,0,-700),1,20,RID(),true,CombatTeams.ENEMY)
	await frames(6)
	check(receiver.hp < receiver_hp,"Enemy swept bullets damage emplacement hitboxes")
	var bomb := MissionBomb.new()
	bomb.impact_effects = scene
	scene.add_child(bomb)
	bomb.global_position = receiver.global_position + Vector3.UP * 6
	bomb.velocity = Vector3.DOWN * 40
	var bomb_hp := receiver.hp
	await frames(30)
	check(receiver.hp < bomb_hp,"Actual bomb impact damages nearby AA")
	var water_before: int = battery.effects.emitted.water
	battery.projectiles.spawn(Vector3(-50000,10,-50000),Vector3(0,-700,-1),1,1,RID(),true,CombatTeams.PLAYER)
	await frames(5)
	check(battery.effects.emitted.water > water_before,"Swept sea impacts emit water splashes")
	var ground_before: int = battery.effects.emitted.ground
	battery.projectiles.spawn(gun.global_position+Vector3(12,20,0),Vector3(0,-700,-1),1,1,RID(),true,CombatTeams.PLAYER)
	await frames(6)
	check(battery.effects.emitted.ground > ground_before,"Swept terrain impacts emit dirt splashes")
	scene.encounters.track_enemy(enemy)
	var count: int = scene.encounters.active.size()
	battery.blast_damage = 1000
	battery._burst(enemy.global_position,null,CombatTeams.PLAYER)
	check(enemy.is_destroyed and scene.encounters.active.size() == count - 1,"AA kill uses actual destruction event and removes active enemy")
	gun.take_damage(1000)
	var shots := gun.shots_fired
	gun.set_physics_process(true)
	await frames(30)
	check(gun.is_destroyed and gun.hp == 0 and gun.shots_fired == shots,"Destroyed gun stops aiming/firing once")
	for kind in ["air","ground","water"]: battery.effects.puff(Vector3.ZERO,kind)
	await frames(240)
	check(battery.projectiles.active.is_empty(),"Missed shells expire and release slots")
	enemy.queue_free()
	scene.restart_malta()
	await frames(15)
	var clean: AirfieldAABattery = scene.malta_mission.world.aa_battery
	check(clean != battery and clean.guns.size() == 6 and get_nodes_in_group("friendly_aa").size() == 6,"Retry replaces battery without duplicate emplacements")
	check(clean.projectiles.active.is_empty() and clean.guns.all(func(g):return g.hp == g.max_hp),"Retry restores health and clears shells/effects")
	print("AA RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed == 0 else 1)
