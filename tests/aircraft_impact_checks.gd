extends SceneTree
var checks: int = 0
var failures: int = 0
var game: Node3D
var plane: FlightAircraft

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS: " if ok else "FAIL: ", message)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func _run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_flight("spitfire")
	plane = game.aircraft
	plane.pilot.automated = true
	game.enemy.ai.combat_enabled = false
	await frames(120)
	check(not plane.is_crashed and plane.gear.contact_count == 3, "Normal stationary landing gear remains supported")
	check(plane.model.gun_ports.size() == 8, "Reference redesign preserves all eight wing gun origins")
	plane.request_reset()
	plane.pending_reset_pose = Transform3D(Basis.IDENTITY, Vector3(0, 9, 500))
	plane.pending_reset_velocity = Vector3(0, -30, -45)
	await frames(100)
	check(plane.is_crashed and plane.impact_effects.started, "Actual hard impact enters crash presentation")
	check(not plane.model.visible, "Intact aircraft hidden after ground breakup")
	check(plane.impact_effects.fragments.size() == 8, "Actual model is split into eight physical fragments")
	var moving: bool = false
	for body in plane.impact_effects.fragments:
		moving = moving or body.linear_velocity.length() > 1
	check(moving, "Fragments use independent rigid-body motion")
	var count := plane.impact_effects.get_child_count()
	plane._crash("duplicate")
	await frames(2)
	check(plane.impact_effects.get_child_count() == count, "Repeated crash does not duplicate fragments or explosion")
	plane.request_reset()
	await frames(3)
	check(plane.model.visible and not plane.impact_effects.started and plane.impact_effects.fragments.is_empty(), "Reset restores intact aircraft and clears debris")
	var gladiator := SeaGladiator.new()
	gladiator.reset_position = Vector3(30, 8, 300)
	game.add_child(gladiator)
	gladiator.pilot.automated = true
	gladiator.request_reset()
	gladiator.pending_reset_pose = Transform3D(Basis.IDENTITY, gladiator.reset_position)
	gladiator.pending_reset_velocity = Vector3(0, -30, -35)
	await frames(100)
	check(gladiator.is_crashed and gladiator.impact_effects.fragments.size() == 8, "Sea Gladiator uses the same physical breakup framework")
	gladiator.queue_free()
	await frames(2)
	# Test a real sea plane, without loading or modifying geographic terrain.
	var sea := StaticBody3D.new()
	sea.add_to_group("aircraft_water")
	game.add_child(sea)
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	sea.add_child(shape)
	plane.add_collision_exception_with(sea)
	plane.impact_effects.water_rids.append(sea.get_rid())
	plane.request_reset()
	plane.pending_reset_pose = Transform3D(Basis.IDENTITY, Vector3(20000, 8, 0))
	plane.pending_reset_velocity = Vector3(0, -14, -45)
	await frames(160)
	check(plane.impact_effects.water and plane.is_destroyed, "Sea impact enters fatal water state")
	check(plane.gear.contact_count == 0, "Sea does not support aircraft wheels")
	check(plane.global_position.y < -1, "Aircraft physically plunges below sea surface")
	check(plane.impact_effects.fragments.is_empty() and plane.impact_effects.burst.water_impact, "Water uses splash instead of fireball and dry fragments")
	var depth := plane.global_position.y
	await frames(120)
	check(plane.global_position.y < depth - 1, "Flooded aircraft continues sinking under forces")
	plane.request_reset()
	await frames(3)
	check(not plane.impact_effects.water and not plane.is_destroyed and plane.health.hp == 100, "Retry clears water state and restores health")
	var enemy: EnemyAircraft = game.enemy
	enemy.request_reset()
	enemy.pending_reset_pose = Transform3D(Basis.IDENTITY, Vector3(20000, 6, 150))
	enemy.pending_reset_velocity = Vector3(0, -20, -40)
	# Sea was created after this aircraft: register the fixture explicitly.
	enemy.add_collision_exception_with(sea)
	enemy.impact_effects.water_rids.append(sea.get_rid())
	await frames(120)
	check(enemy.impact_effects.water and enemy.is_destroyed and not enemy.freeze, "Enemy water wreck remains physical rather than freezing on sea")
	check(enemy.impact_count == 1, "Enemy water loss emits exactly one impact event")
	sea.queue_free()
	await frames(2)
	game.start_malta("ta_qali", "spitfire")
	await frames(80)
	plane = game.aircraft
	check(plane.impact_effects.water_rids.size() == 1, "Real Malta fleet automatically registers Mediterranean collision exception")
	plane.pilot.automated = true
	plane.request_reset()
	plane.pending_reset_pose = Transform3D(Basis.IDENTITY, Vector3(60000, 7, 0))
	plane.pending_reset_velocity = Vector3(0, -18, -40)
	await frames(150)
	check(plane.impact_effects.water and plane.global_position.y < -1 and plane.gear.contact_count == 0, "Actual Mediterranean collision plane permits a physical plunge")
	game.restart_malta()
	await frames(80)
	check(not game.aircraft.impact_effects.started and game.aircraft.health.hp == 100 and get_nodes_in_group("aircraft_fragments").is_empty(), "Malta session retry removes old wrecks and water state")
	game.queue_free()
	await frames(3)
	print("AIRCRAFT IMPACT RESULT: ", checks - failures, "/", checks, " passed")
	quit(1 if failures else 0)
