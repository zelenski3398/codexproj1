extends SceneTree
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await physics_frame
func run() -> void:
	var game: Node3D=load("res://main.tscn").instantiate();root.add_child(game)
	game.start_tutorial();await frames(180)
	var tutorial: TutorialMission=game.tutorial
	var mission: MaltaMission=game.malta_mission
	var plane: FlightAircraft=tutorial.second
	tutorial.advance("BOARD_SECOND")
	mission.pilot.global_position=plane.global_position+plane.global_basis.x*6.7
	await frames(3)
	if not mission.board_aircraft(plane):push_error("FAIL: Cannot board glide fixture");quit(1);return
	tutorial.advance("FAILURE_ROUTE")
	var field: MaltaAirfield=mission.world.fields["luqa"]
	plane.request_reset()
	plane.pending_reset_pose=Transform3D(field.global_basis*Basis(Vector3.RIGHT,-.10),tutorial.emergency_setup())
	plane.pending_reset_velocity=-field.global_basis.z*55
	plane.pilot.automated=true;plane.engine_running=true
	await frames(5)
	plane.gear.extended=true
	var touched: bool=false
	var minimum_speed: float=INF
	for tick in 18000:
		var local: Vector3=field.to_local(plane.global_position)
		var height: float=plane.global_position.y-field.to_global(Vector3(local.x,0,local.z)).y
		var distance: float=maxf(local.z-200,40)
		var gamma: float=-atan2(maxf(height-1.18,0),distance)
		var q: float=.5*plane.air_density*maxf(plane.airspeed*plane.airspeed,1)
		var needed_cl: float=plane.mass*9.81/(q*plane.wing_area*plane.components.lift_factor())
		var alpha: float=clampf((needed_cl-plane.lift_at_zero_alpha-plane.devices.flaps*plane.flap_lift_coefficient)/plane.lift_slope,-.08,.22)
		var desired: float=clampf(gamma+alpha+(plane.airspeed-55)*.02,-.30,.15)
		if height<35:plane.devices.command_flaps(true)
		if height<150:
			var wanted_sink: float=-maxf(2.2,height*.08)
			var acceleration: float=clampf((wanted_sink-plane.linear_velocity.y)*1.2,-1,4)
			var flare_cl: float=plane.mass*(9.81+acceleration)/(q*plane.wing_area*plane.components.lift_factor())
			var flare_alpha: float=clampf((flare_cl-plane.lift_at_zero_alpha-plane.devices.flaps*plane.flap_lift_coefficient)/plane.lift_slope,-.08,.24)
			desired=asin(clampf(plane.linear_velocity.y/maxf(plane.airspeed,1),-1,1))+flare_alpha
		var omega: Vector3=plane.global_basis.transposed()*plane.angular_velocity
		plane.pilot.pitch=clampf((desired-plane.rotation.x)*3.5-omega.x*.7,-.7,.7)
		plane.pilot.roll=clampf(-asin(clampf(plane.global_basis.x.y,-1,1))*3.5-omega.z*.7,-.5,.5)
		plane.pilot.throttle=0;plane.pilot.brakes=true
		await physics_frame
		minimum_speed=minf(minimum_speed,plane.airspeed)
		if plane.gear.contact_count>0:touched=true
		if tick%1200==0:print("GLIDE t=",tick/120.0," local=",local," speed=",plane.airspeed," sink=",plane.linear_velocity.y," phase=",tutorial.phase)
		if plane.is_crashed or plane.is_destroyed or (touched and plane.airspeed<.5):break
	await frames(360)
	var ok: bool=touched and not plane.is_crashed and not plane.is_destroyed and tutorial.emergency_landed and plane.components.power_factor()==0 and plane.airspeed<1
	print("TUTORIAL GLIDE RESULT: ","1/1 passed" if ok else "0/1 passed"," touched=",touched," minimum_speed=",minimum_speed," speed=",plane.airspeed," hp=",plane.health.hp," reason=",plane.crash_reason," phase=",tutorial.phase)
	game.queue_free();await frames(5);quit(0 if ok else 1)
