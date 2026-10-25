extends SceneTree
var passed:=0
var failed:=0
var game: Node
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await physics_frame
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failed+=1
	print("PASS: " if ok else "FAIL: ",label)
func fresh(mode: String="interception") -> void:
	if is_instance_valid(game):game.queue_free();await frames(5)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	if mode=="harbour":game.start_harbour()
	elif mode=="aa_defence":game.start_aa_defence()
	else:game.start_malta("ta_qali","spitfire",mode,true)
	await frames(90)
func airborne() -> void:
	check(game.malta_mission.board_nearest(),"Board existing aircraft for airborne completion fixture")
	var plane: FlightAircraft=game.aircraft
	var field: MaltaAirfield=game.field.fields[game.malta_mission.home]
	plane.global_transform=Transform3D(field.global_basis,field.to_global(Vector3(0,500,-100)))
	plane.linear_velocity=-field.global_basis.z*65;plane.angular_velocity=Vector3.ZERO
	plane.pilot.automated=true;plane.pilot.throttle=.6;plane.engine_running=true;plane.gear.extended=false
	await frames(4)
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	await fresh();await airborne()
	var mission: VallettaInterception=game.interception
	var flow: MissionReturn=game.malta_mission.return_flow
	var plane: FlightAircraft=game.aircraft
	plane.health.take_damage(17);plane.components.fuel_remaining=.61
	var pose: Transform3D=plane.global_transform;var velocity: Vector3=plane.linear_velocity
	var identity: int=game.field.get_instance_id();var hp: float=plane.health.hp
	mission._finish(true,"Combat objectives secured")
	check(flow.pending and mission.phase=="RETURNING" and not mission.results.visible and mission.result_count==0,"Airborne victory becomes return phase without premature success panel")
	check(plane.global_transform==pose and plane.linear_velocity==velocity and plane.health.hp==hp and plane.components.fuel_remaining==.61 and plane.engine_running and plane.pilot.throttle==.6,"Return activation preserves exact aircraft state without autopilot or teleport")
	await frames(5)
	check("Return and land" in game.gameplay_hud.objective.text and game.malta_mission.chart.show_objective and flow.marker.visible,"HUD, map and airborne marker guide the landing")
	mission._finish(true,"Duplicate completion")
	check(flow.reason=="Combat objectives secured" and mission.result_count==0,"Repeated win callbacks cannot duplicate or replace the pending result")
	check(not game.encounters.awaiting_confirmation and not game.encounters.ended,"No next enemy or session shutdown during return")
	# Validate rejection independently of actual suspension acceptance below.
	plane.gear.contact_count=3;plane.linear_velocity=Vector3(0,0,-50)
	check(flow.landed_field(plane)=="","Fast airborne/ground pass cannot satisfy landing")
	var saved: Transform3D=plane.global_transform
	plane.global_position=Vector3(3000,1,3000);plane.linear_velocity=Vector3.ZERO;plane.gear.extended=true
	check(flow.landed_field(plane)=="","Sea or unrelated countryside never counts as an airfield")
	plane.global_transform=saved;plane.gear.contact_count=0
	paused=true;var settled: float=flow.settled;await frames(20)
	check(flow.pending and flow.settled==settled and mission.result_count==0,"Pause freezes return settlement and cannot grant success")
	paused=false
	await preload("res://tests/return_landing_fixture.gd").park(game)
	check(plane.gear.contact_count>=2 and not plane.is_crashed and plane.linear_velocity.length()<8,"Real runway suspension and brakes satisfy the landing condition")
	check(mission.success and mission.result_count==1 and mission.results.visible and not flow.pending,"Safe landing shows exactly one completion panel")
	check(game.field.get_instance_id()==identity and game.aircraft==plane and plane.health.hp==hp and absf(plane.components.fuel_remaining-.61)<.001,"Landing preserves world, aircraft identity, damage and fuel")
	mission._finish(true,"Again");await frames(3)
	check(mission.result_count==1,"Post-landing duplicate success remains latched")
	await fresh();await airborne()
	game.interception._finish(true,"Landing approach secured")
	plane=game.aircraft
	# Explicit short-final fixture; the descent, contact, braking and award below
	# use normal forces/controls, without setting contact_count or landed flags.
	var runway: MaltaAirfield=game.field.fields.ta_qali
	plane.global_transform=Transform3D(runway.global_basis*Basis(Vector3.RIGHT,.07),runway.to_global(Vector3(0,3.8,350)))
	plane.linear_velocity=runway.global_basis*Vector3(0,-.9,-46);plane.angular_velocity=Vector3.ZERO
	plane.gear.extended=true;plane.pilot.throttle=.08;plane.pilot.brakes=false
	var touched:=false
	for tick in 3000:
		plane.pilot.pitch=clampf((.085-plane.rotation.x)*3,-.4,.4)
		if plane.gear.contact_count>0:touched=true;plane.pilot.throttle=0;plane.pilot.brakes=true
		await physics_frame
		if game.interception.success or plane.is_crashed:break
	check(touched and not plane.is_crashed and game.interception.success,"Physical short-final descent, wheel touchdown and braking complete the return")

	await fresh();await airborne();game.interception._finish(true,"Secured")
	game.aircraft.is_crashed=true;await frames(3)
	check(game.interception.phase=="FAILED" and game.interception.result_count==1 and not game.malta_mission.return_flow.pending,"Crash before landing fails the return instead of awarding success")
	await fresh();await airborne();game.interception._finish(true,"Secured")
	game.malta_mission.pilot.take_damage(100);await frames(3)
	check(game.interception.phase=="FAILED" and not game.interception.success,"Pilot death during return remains immediate failure")
	await fresh();await airborne();game.interception._finish(true,"Secured")
	var old: MissionReturn=game.malta_mission.return_flow
	game.restart_malta();await frames(30)
	check(not is_instance_valid(old) and not game.malta_mission.return_flow.pending and game.interception.result_count==0,"Retry frees old return controller and all deferred awards")
	await fresh("harbour");await airborne()
	var harbour: HarbourInterception=game.harbour
	harbour._finish(true,"Harbour defended")
	check(harbour.phase=="RETURNING" and not harbour.radio.seen.has("success") and not harbour.results.visible,"Harbour congratulations recording and results wait for landing")
	await frames(30)
	check(not harbour.radio.seen.has("success"),"Congratulations cannot play during the return flight")
	await preload("res://tests/return_landing_fixture.gd").park(game,"luqa")
	check(harbour.phase=="SUCCESS" and harbour.results.visible and harbour.radio.seen.has("success"),"Landing at another friendly airfield releases existing success recording and panel")
	await fresh("survival");await airborne()
	game.encounters.stage=5
	game.encounters.finish_survival(true,"Five stages secured")
	check(game.malta_mission.return_flow.pending and not game.encounters.complete and not game.encounters.survival_results.visible,"Final Survival success waits for landing")
	game.encounters.confirm();check(not game.encounters.spawning,"Return phase cannot start a sixth Survival stage")
	await preload("res://tests/return_landing_fixture.gd").park(game)
	check(game.encounters.complete and game.encounters.survival_results.visible,"Survival completion screen appears after landing")
	await fresh("aa_defence")
	game.aa_defence._finish(true,"Ground defence secured")
	check(game.aa_defence.phase=="SUCCESS" and not game.malta_mission.return_flow.pending,"Ground-based AA success does not force an artificial takeoff")
	await fresh("aa_defence");await airborne()
	game.aa_defence._finish(true,"Airborne fallback secured")
	check(game.aa_defence.phase=="RETURNING" and not game.aa_defence.results.visible,"Airborne AA fallback also requires landing")
	await preload("res://tests/return_landing_fixture.gd").park(game)
	check(game.aa_defence.phase=="SUCCESS" and game.aa_defence.result_count==1,"AA fallback completes once after landing")
	game.queue_free();await frames(6)
	print("MISSION RETURN RESULT: %d/%d passed"%[passed,passed+failed]);quit(1 if failed else 0)
