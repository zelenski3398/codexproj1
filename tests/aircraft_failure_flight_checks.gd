extends SceneTree
var passed: int = 0
var failed: int = 0
var world: Node3D
var plane: FlightAircraft
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1
	print("PASS: " if ok else "FAIL: ",label)
func fixture(position: Vector3, velocity: Vector3) -> void:
	plane.request_reset()
	plane.pending_reset_pose = Transform3D(Basis.IDENTITY,position)
	plane.pending_reset_velocity = velocity
	await frames(5)
	if plane is EnemyAircraft:
		plane.ai.set_physics_process(false)
		plane.rear_gunner.set_physics_process(false)
	plane.pilot.automated = true
	plane.pilot.throttle = 1
	plane.gear.extended = false
func run() -> void:
	world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_flight("spitfire")
	world.enemy.ai.combat_enabled = false
	plane = world.aircraft
	await fixture(Vector3(0,500,500),Vector3(0,0,-55))
	plane.components.apply_damage(&"engine",1000,Vector3.ZERO,false,"mechanical")
	var start: Vector3 = plane.global_position
	await frames(240)
	check(not plane.is_destroyed and not plane.is_crashed and plane.components.power_factor()==0 and plane.global_position.distance_to(start)>70 and plane.airspeed>30,"Engine-out Spitfire remains in real gliding flight for two seconds")
	check(plane.impact_effects.explosion_count==0 and plane.model.visible and not plane.aircraft_audio.idle.playing,"Engine-out glide has no generic explosion or running engine audio")
	await fixture(Vector3(0,500,500),Vector3(0,0,-80))
	plane.components.profile = plane.components.profile.duplicate()
	plane.components.profile.structural_failure_probability = 1000
	plane.components.integrity[&"left_wing"] = 0.15*plane.components.definitions[&"left_wing"].max_integrity
	plane.pilot.pitch = 0.8
	await frames(180)
	check(plane.components.detached.has(&"left_wing") and plane.impact_effects.component_debris_count==1,"High-speed loaded wing fails during actual physics integration")
	check(plane.angular_velocity.length()>0.1 and plane.components.lift_factor()<=0.5,"Separated wing creates real instability and loss of lift")
	# Controlled belly contact against the existing runway, with no fuel fire.
	await fixture(Vector3(0,0.48,500),Vector3(0,-1,-22))
	plane.components.fuel_remaining = 0
	plane.pilot.throttle = 0
	await frames(90)
	check(plane.is_crashed and plane.impact_effects.crash_result.get("category")=="controlled" and plane.model.visible,"Actual shallow low-speed belly landing retains recognizable intact fuselage")
	check(plane.impact_effects.explosion_count==0 and plane.impact_effects.fragments.is_empty(),"Controlled landing produces dust without full fragmentation/fireball")
	var bomber := ItalianEnemy.new()
	bomber.definition = EnemyAircraftDefinition.find("sm79")
	bomber.reset_position = Vector3(300,600,500)
	world.add_child(bomber)
	plane = bomber
	await fixture(Vector3(300,600,500),Vector3(0,0,-65))
	plane.components.apply_damage(&"engine_left",1000,Vector3.ZERO,false,"mechanical")
	await frames(120)
	check(not plane.is_destroyed and plane.global_position.y>500 and is_equal_approx(plane.components.power_factor(),2.0/3.0),"SM.79 continues airborne with two engines after real single-engine failure")
	check(absf(plane.angular_velocity.y)>0.01,"Single SM.79 wing-engine loss produces actual asymmetric yaw")
	plane.components.apply_damage(&"engine",1000,Vector3.ZERO,false,"mechanical")
	plane.components.apply_damage(&"engine_right",1000,Vector3.ZERO,false,"mechanical")
	await frames(120)
	check(not plane.is_destroyed and plane.components.power_factor()==0 and plane.impact_effects.explosion_count==0,"Triple engine failure forces powerless bomber flight without an automatic kill/explosion")
	# Multiple simultaneous catastrophic events share one capped debris budget.
	var pieces: Array[FlightAircraft] = []
	for i in 10:
		var aircraft := FlightAircraft.new()
		aircraft.reset_position = Vector3(100+i*20,800,500)
		world.add_child(aircraft)
		aircraft.pilot.automated = true
		pieces.append(aircraft)
	await frames(2)
	for aircraft in pieces: aircraft.components.catastrophic_failure("Concurrent destruction fixture")
	await frames(5)
	var fragments := get_nodes_in_group("aircraft_fragments")
	var colliding: int = 0
	for fragment in fragments:
		if fragment.collision_mask != 0: colliding+=1
	check(fragments.size()<=64 and colliding<=32,"Ten simultaneous losses respect global fragment and collision budgets")
	check(pieces.all(func(a):return a.is_destroyed and a.impact_effects.explosion_count==1),"Concurrent losses each notify and explode once")
	world.show_selection()
	await frames(5)
	check(get_nodes_in_group("aircraft_fragments").is_empty() and get_nodes_in_group("aircraft_major_debris").is_empty(),"Session teardown clears both full-wreck and detached-component debris")
	world.queue_free()
	await frames(10)
	print("FAILURE FLIGHT RESULT: ",passed,"/",passed+failed," passed")
	quit(1 if failed else 0)
