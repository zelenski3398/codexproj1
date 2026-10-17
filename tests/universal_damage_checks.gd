extends SceneTree
var passed: int = 0
var failed: int = 0
var session: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1
	print("PASS: " if ok else "FAIL: ",label)
func make(kind: String) -> FlightAircraft:
	var plane: FlightAircraft
	if kind == "spitfire": plane = FlightAircraft.new()
	elif kind == "sea_gladiator": plane = SeaGladiator.new()
	elif kind == "stuka": plane = EnemyAircraft.new()
	else:
		plane = ItalianEnemy.new()
		plane.definition = EnemyAircraftDefinition.find(kind)
	plane.reset_position = Vector3(1500,800,1200)
	session.add_child(plane)
	plane.request_reset()
	plane.pending_reset_pose = Transform3D(Basis.IDENTITY,plane.reset_position)
	plane.pending_reset_velocity = Vector3(0,0,-50)
	if plane is EnemyAircraft:
		plane.ai.set_physics_process(false)
		plane.rear_gunner.set_physics_process(false)
	plane.pilot.automated = true
	return plane
func run() -> void:
	session = load("res://main.tscn").instantiate()
	root.add_child(session)
	for kind in ["spitfire","sea_gladiator","stuka","cr42","c200","c202","sm79"]:
		var plane := make(kind)
		await frames(5)
		plane.freeze = true
		var damage := plane.components
		check(damage.definitions.size() == (18 if kind=="sm79" else 12),kind+": model-specific component set with actual sensors")
		check(damage.component_ids("engine").size() == (3 if kind=="sm79" else 1),kind+": correct independent engine count")
		damage.apply_damage(&"engine",10000,Vector3.ZERO,false,"mechanical")
		check(damage.engine_power(&"engine") == 0 and not plane.is_destroyed and plane.health.hp > 85,kind+": engine fails without airframe explosion or combat-loss event")
		plane._process(0.1)
		check(plane.model.engine_factors[0] == 0 and plane.impact_effects.explosion_count==0,kind+": failed propeller receives zero power")
		if kind == "sm79":
			check(is_equal_approx(damage.power_factor(),2.0/3.0),"SM.79: remaining two engines retain 2/3 available thrust")
			damage.apply_damage(&"engine_left",1000,Vector3.ZERO,false,"mechanical")
			check(is_equal_approx(damage.power_factor(),1.0/3.0) and absf(damage.asymmetry_torque(10000,Basis.IDENTITY).y)>1000,"SM.79: independent wing-engine failure creates force-derived asymmetric yaw")
			check(damage.integrity_ratio(&"engine_right")==1 and not plane.is_destroyed,"SM.79: third engine and bomber remain operational")
			damage.apply_damage(&"rear_gunner",10000)
			check(damage.integrity_ratio(&"cockpit")==1,"SM.79: gunner damage is independent of pilot cockpit")
		damage.reset();plane.health.reset()
		damage.apply_damage(&"fuel_tank",20,Vector3.ZERO,false,"mechanical")
		damage.leaking_tanks[&"fuel_tank"] = true
		damage.fires.clear()
		var fuel := damage.fuel_remaining
		damage.advance(1)
		check(damage.fuel_remaining<fuel and damage.power_factor()==1,kind+": leak reduces endurance without prematurely reducing power")
		damage.fuel_remaining = 0
		check(damage.power_factor()==0,kind+": empty tanks starve engines")
		damage.reset();plane.health.reset()
		damage.apply_damage(&"rudder",10000,Vector3.ZERO,false,"mechanical")
		damage.apply_damage(&"elevator",10000,Vector3.ZERO,false,"mechanical")
		check(damage.rudder_factor()==0 and damage.elevator_factor()==0,kind+": failed controls have no authority")
		damage.reset();plane.health.reset()
		damage.integrity[&"left_wing"] = damage.definitions[&"left_wing"].max_integrity*0.15
		damage.profile = damage.profile.duplicate()
		damage.profile.structural_failure_probability = 0
		damage.profile.structural_fatigue_rate = 0
		damage.structure_clock = 1
		damage.velocity_valid = false
		damage.evaluate_structure(.25,Vector3(0,0,-40),Vector3.ZERO)
		check(not damage.detached.has(&"left_wing"),kind+": critical wing remains attached under gentle load")
		damage.profile.structural_failure_probability = 1000
		damage.structure_clock = 1
		damage.last_velocity = Vector3(0,-30,-120)
		damage.evaluate_structure(.25,Vector3(0,0,-120),Vector3.ZERO)
		await frames(3)
		check(damage.detached.has(&"left_wing") and damage.wing_efficiency(&"left_wing")==0 and plane.impact_effects.component_debris_count==1,kind+": loaded critical wing separates actual geometry with lift loss")
		var count := plane.impact_effects.component_debris_count
		damage.detach(&"left_wing")
		await frames(2)
		check(count==plane.impact_effects.component_debris_count,kind+": no duplicate detachment")
		plane.impact_effects.reset();damage.reset();plane.health.reset()
		check(plane.impact_effects.original_meshes.is_empty() and plane.model.visible,kind+": reset restores original geometry and clears detached objects")
		# Generic hull depletion is deliberately non-explosive.
		plane.take_damage(10000)
		await frames(2)
		check(plane.is_destroyed and plane.impact_effects.explosion_count==0 and plane.model.visible,kind+": zero hull HP disables intact wreck without a generic fireball")
		plane.queue_free()
		await frames(3)
	var plane := make("spitfire")
	await frames(5)
	plane.freeze = true
	var damage := plane.components
	var shallow := AircraftCrashSolver.assess(plane,Vector3(0,-1,-45),Vector3.UP)
	var steep := AircraftCrashSolver.assess(plane,Vector3(0,-44,-10),Vector3.UP)
	check(shallow.category=="controlled" and steep.severity>shallow.severity*10,"Equal-speed shallow and steep impacts produce different energy/severity")
	plane.components.fuel_remaining=0
	var high := AircraftCrashSolver.assess(plane,Vector3(0,-130,-90),Vector3.UP)
	check(high.category=="catastrophic" and not high.ignition,"Empty-fuel catastrophic impact cannot create a fuel explosion")
	var gentle := AircraftCrashSolver.assess(plane,Vector3(0,-1,-22),Vector3.UP)
	check(gentle.category=="controlled" and not gentle.ignition,"Low-energy landing cannot randomly detonate")
	damage.reset()
	damage.profile = damage.profile.duplicate()
	damage.profile.fire_spread_probability_per_second=1000
	damage.integrity[&"fuel_tank"]=damage.definitions[&"fuel_tank"].max_integrity*0.6
	damage.ignite(&"engine")
	var before: float = damage.integrity[&"engine"]
	damage.advance(1)
	check(damage.integrity[&"engine"]<before and damage.fires.has(&"fuel_tank") and not damage.fires.has(&"rudder"),"Fire damages source and spreads only through configured adjacency")
	plane.engine_running=false
	damage.advance(1)
	check(not damage.fires.is_empty(),"Switching off engine does not extinguish an existing fire")
	damage.fuel_remaining=0
	damage.advance(1)
	check(not damage.fires.has(&"fuel_tank"),"Fuel exhaustion extinguishes tank fire")
	damage.reset();plane.health.reset()
	damage.catastrophic_failure("Debug catastrophic ignition")
	await frames(3)
	check(plane.is_destroyed and plane.impact_effects.explosion_count==1 and not plane.model.visible and plane.impact_effects.fragments.size()>0,"Explicit catastrophic failure gives one physical breakup and fireball")
	damage.catastrophic_failure("duplicate")
	await frames(2)
	check(plane.impact_effects.explosion_count==1,"Catastrophic callbacks cannot duplicate explosion")
	plane.queue_free()
	session.queue_free()
	await frames(10)
	print("UNIVERSAL DAMAGE RESULT: ",passed,"/",passed+failed," passed")
	quit(1 if failed else 0)
