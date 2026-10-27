extends SceneTree
var passed:=0
var failed:=0
var plane: HawkerHurricane
func _initialize() -> void:call_deferred("run")
func frames(n: int=4) -> void:
	for i in n:await physics_frame
func check(ok: bool,label: String) -> void:
	if ok:passed+=1;print("PASS: ",label)
	else:failed+=1;push_error("FAIL: "+label)
func fixture(point: Vector3,velocity: Vector3,pitch: float=0) -> void:
	plane.request_reset();plane.pending_reset_pose=Transform3D(Basis(Vector3.RIGHT,pitch),point);plane.pending_reset_velocity=velocity
	await frames(3);plane.engine_running=true;plane.pilot.automated=true
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.start_flight("hurricane");await frames(180);plane=game.aircraft
	game.enemy.ai.set_physics_process(false);game.enemy.freeze=true
	plane.pilot.automated=true;plane.pilot.brakes=false
	check(plane.gear.contact_count==3 and not plane.is_crashed,"Hurricane normal three-wheel parking on retained test airfield")
	plane.pilot.throttle=.35;await frames(360)
	check(plane.airspeed>2 and plane.airspeed<30 and not plane.is_crashed,"Shared forces support low-power taxi")
	plane.pilot.throttle=1
	for tick in 4200:
		plane.pilot.pitch=clampf((.10-plane.rotation.x)*3,-.5,.5) if plane.airspeed>36 else 0
		plane.pilot.roll=clampf(-plane.global_basis.x.y*3-plane.angular_velocity.z*.4,-.5,.5)
		await physics_frame
		if plane.altitude>60 or plane.is_crashed:break
	print("TAKEOFF speed=",plane.airspeed," AGL=",plane.altitude," reason=",plane.crash_reason)
	check(plane.altitude>30 and not plane.is_crashed and plane.gear.contact_count==0,"Hurricane accelerates and takes off using normal forces and controls")
	check(plane.gear.toggle() and not plane.gear.extended,"Existing G-equivalent toggle retracts airborne main gear")
	await frames(200)
	check(not plane.model.wheel_roots[0].visible and plane.model.wheel_roots[2].visible,"Retracted main wheels disappear into wings while tailwheel stays visible")
	var bank: float=absf(plane.global_basis.x.y)
	plane.pilot.roll=.35;await frames(60)
	check(absf(plane.global_basis.x.y)>bank+.02 and absf(plane.model.ailerons[0].rotation.x)>.02,"Normal roll input banks the aircraft and animates its separate ailerons")
	plane.pilot.roll=0
	await fixture(Vector3(0,250,500),Vector3(0,0,-60))
	game.enemy.reset_pending=false;game.enemy.global_position=Vector3(0,250,250);game.enemy.health.reset()
	var hp: float=game.enemy.health.hp
	plane.pilot.fire=true;await frames(60);plane.pilot.fire=false
	check(plane.guns.pool.total_spawned>=8 and game.enemy.health.hp<hp,"All eight physical .303 projectiles damage the enemy through swept shared collision")
	var power: float=plane.components.power_factor()
	plane.components.apply_damage(&"engine",30,plane.global_position)
	check(plane.components.power_factor()<power,"Engine component damage reduces available Hurricane thrust")
	plane.take_damage(55);await frames()
	check(plane.health.hp<50 and plane.damage_effects.emitting and not plane.is_destroyed,"Shared below-half-health smoke/fire activates on the Hurricane")
	plane.components.apply_damage(&"fuel_tank",5,plane.global_position,true);await frames()
	check(plane.components.leaking_tanks.has(&"fuel_tank") and plane.components.fires.has(&"fuel_tank"),"Configured Hurricane tank retains fuel leak/fire hazards")
	await fixture(Vector3(0,3.6,350),Vector3(0,-.65,-41),.08)
	plane.pilot.throttle=.03;plane.gear.extended=true
	var touched:=false
	for tick in 2400:
		plane.pilot.pitch=clampf((.085-plane.rotation.x)*3,-.4,.4)
		if plane.gear.contact_count>0:touched=true;plane.pilot.throttle=0;plane.pilot.brakes=true
		await physics_frame
		if plane.is_crashed or (touched and plane.airspeed<.5):break
	print("LANDING touched=",touched," speed=",plane.airspeed," reason=",plane.crash_reason)
	check(touched and not plane.is_crashed and plane.airspeed<1,"Configured Hurricane lands and wheel brakes stop it under the shared flight model")
	await fixture(Vector3(0,140,500),Vector3(0,0,-130))
	game.enemy.freeze=false;game.enemy.request_reset()
	game.enemy.pending_reset_pose=Transform3D(Basis(Vector3.UP,PI),plane.global_position+Vector3(0,0,-22));game.enemy.pending_reset_velocity=Vector3(0,0,70)
	plane.gear.extended=false;await frames(120)
	check(plane.is_crashed and plane.impact_effects.started,"Hurricane high-speed aircraft collision invokes shared destruction")
	game.enemy.freeze=true
	await fixture(Vector3(0,10,500),Vector3(0,-85,-65));await frames(100)
	check(plane.is_crashed and plane.impact_effects.started and not plane.model.visible,"Severe land crash uses existing breakup and destruction effects")
	var sea:=StaticBody3D.new();sea.add_to_group("aircraft_water");game.add_child(sea)
	var shape:=CollisionShape3D.new();shape.shape=WorldBoundaryShape3D.new();sea.add_child(shape)
	plane.add_collision_exception_with(sea);plane.impact_effects.water_rids.append(sea.get_rid())
	await fixture(Vector3(20000,8,0),Vector3(0,-14,-45));await frames(160)
	check(plane.is_destroyed and plane.impact_effects.water and plane.global_position.y< -1 and plane.gear.contact_count==0,"Hurricane plunges physically into water rather than landing on it")
	check(plane.impact_effects.fragments.is_empty() and plane.impact_effects.burst.water_impact,"Sea crash uses the shared splash and sinking presentation")
	game.queue_free();await frames();print("HURRICANE FLIGHT RESULT: %d/%d passed"%[passed,passed+failed]);quit(1 if failed else 0)
