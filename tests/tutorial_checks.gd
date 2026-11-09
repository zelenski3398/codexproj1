extends SceneTree
var passed: int=0
var failed: int=0
var game: Node3D
var tutorial: TutorialMission
var mission: MaltaMission
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await physics_frame
func check(ok: bool,text: String) -> void:
	if ok:passed+=1
	else:failed+=1
	print("PASS: " if ok else "FAIL: ",text)
func pose(plane: FlightAircraft,point: Vector3,basis: Basis=Basis.IDENTITY,velocity: Vector3=Vector3.ZERO) -> void:
	# Test setup only. Preserve actual component/fuel/health state while placing
	# each stage's boundary condition; this is not an end-to-end flight claim.
	plane.freeze=true;await frames(2)
	plane.global_transform=Transform3D(basis,point)
	plane.linear_velocity=velocity;plane.angular_velocity=Vector3.ZERO
	plane.previous_contact_velocity=velocity;plane.airborne_time=0
	plane.pilot.automated=true;plane.pilot.throttle=0;plane.pilot.brakes=true
	await frames(2);plane.freeze=false;await frames(4)
func ground(plane: FlightAircraft,id: String) -> void:
	var field: MaltaAirfield=mission.world.fields[id]
	plane.gear.extended=true
	await pose(plane,field.to_global(Vector3(0,1.18,0)),field.global_basis*Basis(Vector3.RIGHT,.117))
	await frames(420)
func key(code: Key) -> void:
	var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=true
	Input.parse_input_event(e);await frames(2)
	e.pressed=false;Input.parse_input_event(e);await frames(2)
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await frames(3);game.show_intro()
	var poster: GameIntro=game.startup_intro;poster.set_process(false)
	check(poster.tutorial_button.disabled,"Tutorial button is shielded during the opening dissolve")
	poster._process(4.1)
	check(not poster.tutorial_button.disabled and Rect2(Vector2.ZERO,poster.artwork.size).encloses(Rect2(poster.tutorial_button.position,poster.tutorial_button.size)),"Tutorial is integrated inside the poster and enabled after reveal")
	poster.begin_tutorial();poster.begin_tutorial();poster._process(1.7);poster._process(1.7)
	await frames(180)
	tutorial=game.tutorial;mission=game.malta_mission
	if tutorial==null:check(false,"Poster launches tutorial");quit(1);return
	var world_id:=mission.world.get_instance_id()
	var normal_settings: Dictionary=game._ai_settings.duplicate(true)
	check(game.game_mode=="tutorial" and tutorial.phase=="BOARD" and game.startup_intro==null,"Poster Tutorial launches exactly one fresh training session")
	check(tutorial.first is SeaGladiator and tutorial.second != null and tutorial.second.display_name=="Spitfire Mk I","Assigned Gladiator and second Spitfire are available")
	check(game.encounters.active.is_empty() and tutorial.spawn_count==0,"No combat aircraft spawn before training route")
	check(game.gameplay_hud.controls_panel.visible and game.gameplay_hud.basic_controls.text.contains("Q") and game.gameplay_hud.basic_controls.text.contains("Guns") and game.gameplay_hud.basic_controls.text.contains("F1"),"Top-left controls include actual device, firing and help bindings")
	check(not mission.board_aircraft(tutorial.second),"Tutorial rejects boarding the wrong lesson aircraft")
	check(mission.board_nearest(),"Pilot boards nearby assigned Gladiator through normal interaction")
	await frames(4);check(tutorial.phase=="ENGINE","Actual boarding advances to engine lesson")
	await key(KEY_I);check(tutorial.first.engine_running,"Existing I starts the training aircraft engine")
	await pose(tutorial.first,Vector3(3000,300,4750),Basis.IDENTITY,Vector3(0,0,-48))
	tutorial.first.pilot.throttle=.7;await frames(8)
	check(tutorial.phase=="NAVIGATION","Airborne state advances taxi/takeoff lessons")
	await frames(10);check(tutorial.route_index==0,"Checkpoint waits for control practice rather than skipping the lesson")
	for code in [KEY_DOWN,KEY_LEFT,KEY_A,KEY_S,KEY_M]:await key(code)
	if mission.chart_panel.visible:await key(KEY_M)
	for i in 3:
		await pose(tutorial.first,tutorial.route[i],Basis.IDENTITY,Vector3(0,0,-48));await frames(8)
	check(tutorial.phase=="AIR_COMBAT" and tutorial.spawn_count==1 and game.encounters.active.size()==1,"Sequential terrain-safe route spawns exactly one Stuka over Valletta")
	check(tutorial.foe.global_position.distance_to(MaltaGeography.vector(MaltaGeography.data().landmarks[0].position))<1600,"First encounter is geographically over Valletta")
	check(tutorial.foe.ai.aim_error_degrees==tutorial.lessons.enemy_aim_error_degrees and tutorial.foe.rear_gunner.skill_level==0,"Training opponent uses local forgiving aiming and Cadet rear gunner")
	tutorial.foe.take_damage(60);await frames(3)
	check(tutorial.phase=="AIR_COMBAT","Smoke and low HP do not count as a kill")
	tutorial.foe.take_damage(100);await frames(4)
	check(game._ai_settings==normal_settings,"Training enemy tuning does not leak into normal encounters")
	check(tutorial.phase=="RETURN" and tutorial.kills==1,"Actual enemy destruction requests landing, not an early result")
	await ground(tutorial.first,"ta_qali")
	check(tutorial.phase=="TAXI_HANDOVER","Landing away from the hangar advances to taxi guidance, not an early exit")
	tutorial.first.engine_running=false
	check(not mission.leave_aircraft() and mission.occupied==tutorial.first and "green stand" in mission.notice,"Even after shutdown, distant-runway exit is blocked with handover guidance")
	tutorial.first.engine_running=true
	var base: MaltaAirfield=mission.world.fields["ta_qali"]
	var band: Vector3=base.to_local(tutorial.landing_position)
	check(absf(band.x)<.1 and absf(band.z)+tutorial.lessons.landing_sector_length*.5<base.runway_length*.5,"Marked touchdown sector stays inside the existing runway")
	check(tutorial.handover_point().distance_to(tutorial.second.global_position)<tutorial.lessons.handover_maximum_walk,"Handover stand is a short walk from the actual Spitfire")
	var cross: Array[Vector3]=tutorial.handover_taxi_points()
	check(is_equal_approx(base.to_local(cross[1]).z,base.runway_length*.31),"Taxi guidance crosses through the clear central gap between AA emplacements")
	await pose(tutorial.first,tutorial.handover_point()+base.global_basis.y*1.18,base.global_basis*Basis(Vector3.RIGHT,.117))
	await frames(420)
	check(tutorial.phase=="SHUTDOWN" and tutorial.handover_ready(),"Only settled parking in the green stand unlocks shutdown and exit")
	tutorial.first.engine_running=false;tutorial.first.pilot.throttle=0;tutorial.first.take_damage(10)
	check(mission.leave_aircraft(),"Existing safe dismount exits the landed Gladiator")
	check(mission.pilot.global_position.distance_to(tutorial.second.global_position)<55,"Actual safe exit leaves the pilot within a short walk of the Spitfire")
	await frames(4)
	mission.pilot.global_position=tutorial.second.global_position+tutorial.second.global_basis.x*6.7
	await frames(3);check(mission.board_aircraft(tutorial.second),"Player can board the second plane without reloading the world")
	await frames(3);tutorial.second.engine_running=true
	await pose(tutorial.second,Vector3(3000,400,4700),Basis.IDENTITY,Vector3(0,0,-55))
	tutorial.second.pilot.throttle=.6;await frames(10)
	check(tutorial.phase=="DEVICES","Second takeoff reaches gear/flap practice")
	tutorial.second.gear.toggle();tutorial.second.devices.command_flaps(true)
	await frames(320)
	tutorial.second.devices.command_flaps(false);await frames(340)
	check(tutorial.phase=="FAILURE_ROUTE" and tutorial.flap_deployed_seen and tutorial.gear_retracted_seen,"Real gear movement and flap extension/retraction complete the devices lesson")
	await pose(tutorial.second,tutorial.emergency_setup(),Basis.IDENTITY,Vector3(0,0,-55))
	await frames(6)
	check(tutorial.phase=="EMERGENCY" and tutorial.damage_count==1 and tutorial.second.components.power_factor()==0,"Training entry triggers one real engine-component failure")
	var velocity:=tutorial.second.linear_velocity;tutorial.apply_training_damage()
	check(tutorial.damage_count==1 and tutorial.second.linear_velocity==velocity and tutorial.second.health.hp<=45 and not tutorial.second.is_destroyed,"Repeated failure trigger cannot repeat damage or overwrite velocity; aircraft remains landable")
	await ground(tutorial.second,"luqa")
	check(tutorial.phase=="EXIT_DAMAGED" and tutorial.emergency_landed,"Emergency lesson requires a genuine settled landing at the designated alternate")
	tutorial.second.pilot.throttle=0
	if tutorial.second.engine_running:await key(KEY_I)
	check(not tutorial.second.engine_running,"I can shut down a failed engine before leaving; it does not trap the pilot")
	await key(KEY_I)
	check(not tutorial.second.engine_running,"I cannot restart the mechanically failed engine")
	check(mission.leave_aircraft(),"Pilot can leave the stopped damaged aircraft")
	await frames(5)
	check(tutorial.phase=="CALL_TRANSPORT" and mission.recovery.available(),"Tutorial allows V pickup after emergency landing even at the alternate airfield")
	mission.recovery.response_seconds=.05
	await key(KEY_V);await frames(500)
	check(tutorial.phase=="TRUCK" and mission.recovery.state=="READY" and is_instance_valid(mission.recovery.truck),"Existing V recovery spawns one real pickup vehicle")
	if not is_instance_valid(mission.recovery.truck):quit(1);return
	mission.pilot.global_position=mission.recovery.truck.global_position+Vector3(2,1,0)
	await frames(3)
	check(mission.recovery.enter(mission.recovery.truck),"Entering the nearby recovery truck explicitly begins return")
	await frames(360)
	check(tutorial.phase=="MOUNT_AA" and mission.recovery.returns==1,"Truck return advances to AA at home base")
	check(mission.world.get_instance_id()==world_id and tutorial.first.health.hp==90 and tutorial.second.health.hp<=45 and tutorial.second.components.power_factor()==0,"Recovery preserves the continuous world and both aircraft damage states")
	var gun: BritishAAGun=tutorial.guns.back()
	mission.pilot.global_position=mission.interaction.find_exit(gun,5)
	await frames(5)
	check(mission.interaction.mount_gun(gun),"Existing manual interaction mounts a home-base gun")
	await frames(5)
	check(tutorial.phase=="AA_COMBAT" and tutorial.spawn_count==2 and tutorial.foe.ai is DiveAttackPilot,"Mounting launches exactly one physical dive-attack Stuka, using existing AI")
	check(tutorial.guns.filter(func(g):return g.shots_fired>0).is_empty(),"Unoccupied AA guns have not fired autonomously")
	gun.fire_round();check(gun.shots_fired==1,"Occupied gun fires through its normal projectile system")
	tutorial.release_bomb(tutorial.foe)
	tutorial.foe.take_damage(100);await frames(3)
	check(tutorial.phase=="DRAINING" and tutorial.kills==2,"Final kill waits for unresolved physical ordnance")
	for bomb in tutorial.effects.get_children():
		if bomb is MissionBomb:bomb.queue_free()
	await frames(5)
	check(tutorial.phase=="SUCCESS" and tutorial.results.visible and mission.interaction.occupied_gun==null,"Successful tutorial presents results once and restores on-foot control")
	var sessions: int=game.session_number
	tutorial.choose_result(true);tutorial.choose_result(true);await frames(120)
	check(game.session_number==sessions+1,"Repeated Retry presses queue exactly one clean tutorial restart")
	check(game.tutorial!=tutorial and game.tutorial.phase=="BOARD" and game.tutorial.spawn_count==0 and game.encounters.active.is_empty(),"Retry clears tutorial steps, enemies, damage trigger and old ordnance")
	mission=game.malta_mission
	var rescue: TutorialMission=game.tutorial
	check(mission.board_nearest(),"Fresh attempt can board for disabled-engine handover coverage")
	rescue.advance("RETURN")
	var engine: AircraftComponentDefinition=rescue.first.components.definitions[&"engine"]
	rescue.first.components.apply_damage(&"engine",engine.max_integrity/engine.damage_multiplier,rescue.first.global_position,false,"training")
	await ground(rescue.first,"ta_qali")
	check(rescue.phase=="FIRST_RECOVERY","A disabled Gladiator is offered recovery instead of an impossible taxi")
	rescue.first.engine_running=false
	check(mission.leave_aircraft() and mission.recovery.request(),"Disabled-engine exception permits safe exit and a short truck pickup")
	game.malta_mission.pilot.take_damage(100);await frames(4)
	check(game.tutorial.phase=="FAILED" and not game.malta_mission.survival.death_panel.visible and game.tutorial.results.visible,"Pilot death ends training with one result panel and blocks further spawns")
	game.show_selection(false);await frames(5)
	check(game.tutorial==null and game.malta_mission==null,"Leaving tutorial removes its director and world cleanly")
	game.queue_free();await frames(5)
	print("TUTORIAL RESULT: %d/%d passed"%[passed,passed+failed]);quit(1 if failed else 0)
