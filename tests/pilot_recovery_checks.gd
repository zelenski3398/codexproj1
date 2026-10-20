extends SceneTree
var passed:=0
var failed:=0
var game: Node3D
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await physics_frame
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failed+=1
	print("PASS: " if ok else "FAIL: ",label)
func key(code: Key) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.pressed=true;Input.parse_input_event(event)
	event=InputEventKey.new();event.keycode=code;event.pressed=false;Input.parse_input_event(event)
func ready_game(mode: String="encounter") -> void:
	if game!=null:game.queue_free();await frames(8)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.start_malta("ta_qali","spitfire",mode)
	await frames(180)
func disable_nearby() -> FlightAircraft:
	var mission: MaltaMission=game.malta_mission
	check(mission.board_nearest(),"Board selected live hangar aircraft normally")
	var aircraft: FlightAircraft=mission.occupied
	# Explicit crash-location fixture; recovery never moves/repairs this body.
	var field: MaltaAirfield=mission.world.fields.ta_qali
	aircraft.request_reset()
	aircraft.pending_reset_pose=field.global_transform*Transform3D(Basis(Vector3.RIGHT,.117),Vector3(-120,1.18,100))
	await frames(10)
	aircraft.pilot.automated=true
	aircraft.pilot.brakes=true
	aircraft.take_damage(1000)
	await frames(8)
	return aircraft
func collect_truck(recovery: TransportRecovery) -> void:
	for i in 1200:
		await physics_frame
		if recovery.state=="READY":break
	check(recovery.state=="READY" and recovery.truck!=null,"Exactly one support truck becomes available after the response delay")
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.selector.select("sea_gladiator");key(KEY_ENTER)
	await frames(180)
	var mission: MaltaMission=game.malta_mission
	check(mission!=null and game.environment_id=="malta" and mission.initial_aircraft is SeaGladiator,"Fresh main-menu Enter defaults directly to Malta with selected Gladiator")
	check(mission.pilot.active and mission.nearest_serviceable()==mission.initial_aircraft,"Pilot starts on foot beside that exact aircraft")
	for aircraft in mission.fleet:
		var inside:=false
		for field in mission.world.fields.values():
			for hangar in field.installations:
				var local: Vector3=hangar.to_local(aircraft.global_position)
				if absf(local.x)<18 and absf(local.z)<13:inside=true
		check(inside and aircraft.gear.contact_count==3 and aircraft.airspeed<.3 and not aircraft.engine_running,"Every base aircraft rests stably inside a hangar with engine stopped")
	await ready_game()
	mission=game.malta_mission
	var aircraft:=await disable_nearby()
	var world_id:=mission.world.get_instance_id()
	var ids: Array=mission.fleet.map(func(a):return a.get_instance_id())
	check(aircraft.is_destroyed and mission.pilot.health.hp==100 and not game.encounters.ended,"Zero aircraft HP neither kills pilot nor ends running encounter")
	paused=true
	game.hud._process(0)
	check(not game.hud.resume_button.disabled and game.hud.overlay_title.text.contains("PILOT ALIVE"),"Paused survivor can resume after hull loss; UI does not declare pilot dead")
	paused=false
	mission.pilot.take_damage(17)
	check(mission.leave_aircraft() and mission.pilot.active,"Living pilot exits disabled aircraft with normal E transition")
	check(aircraft.is_destroyed and aircraft.health.hp==0 and not aircraft.input_enabled,"Abandoned wreck remains destroyed and cannot receive controls")
	var rec: TransportRecovery=mission.recovery
	key(KEY_V)
	key(KEY_V)
	await frames(2)
	check(rec.state=="REQUESTED" and not rec.request() and rec.requests==1,"Real V input requests assistance once; repeated input is latched")
	var before:=mission.pilot.global_position
	await frames(500)
	check(rec.truck==null and rec.state=="REQUESTED" and mission.pilot.global_position.distance_to(before)<.5,"Response delay does not teleport pilot or create a premature truck")
	await collect_truck(rec)
	check(mission.world.trucks.size()==4 and mission.pilot.global_position.distance_to(before)<.5,"Truck arrival alone leaves pilot and world in place")
	check(not rec.enter(rec.truck),"Remote entry cannot trigger return")
	# Walking-position fixture only: exercise existing nearest-object E routing.
	mission.pilot.global_position=mission.interaction.find_exit(rec.truck,2.5)
	await frames(5)
	key(KEY_E)
	await frames(3)
	check(rec.state=="RETURNING" and not mission.pilot.active,"Explicit nearby E entry starts faded return and disables walking input")
	for i in 400:
		await physics_frame
		if rec.state=="IDLE":break
	check(rec.returns==1 and rec.truck==null and mission.world.trucks.size()==3,"Return consumes the one recovery truck and clears the request")
	check(mission.world.get_instance_id()==world_id and mission.fleet.map(func(a):return a.get_instance_id())==ids and aircraft.health.hp==0,"Recovery preserves world, aircraft identities and abandoned wreck health")
	check(mission.pilot.health.hp==83 and mission.pilot.active and mission.pilot.camera.current,"Recovery preserves pilot health and restores on-foot camera/control")
	check(mission.nearest_serviceable()!=null and mission.nearest_serviceable()!=aircraft and mission.board_nearest(),"Replacement aircraft remains available and boardable after recovery")
	# A second recovery in this same world must be possible without cloning
	# either the pilot, fleet or old recovery truck.
	mission.occupied.take_damage(1000)
	await frames(4)
	rec.response_seconds=.02
	check(mission.leave_aircraft() and rec.request(),"Same survivor can request a second recovery after losing the replacement")
	await collect_truck(rec)
	mission.pilot.global_position=mission.interaction.find_exit(rec.truck,2.5)
	await frames(3)
	check(mission.interaction.interact(),"Second pickup still requires explicit truck entry")
	await frames(200)
	check(rec.returns==2 and rec.state=="IDLE" and mission.world.trucks.size()==3 and mission.fleet.map(func(a):return a.get_instance_id())==ids and mission.pilot.health.hp==83,"Two recoveries preserve the same damaged fleet and pilot without duplicate vehicles")
	await ready_game("survival")
	mission=game.malta_mission
	aircraft=await disable_nearby()
	var foes: Array=game.encounters.active.map(func(a):return a.get_instance_id())
	check(not game.encounters.ended and game.encounters.stage==1,"Survival remains active when only the airframe is lost")
	check(mission.leave_aircraft(),"Survival pilot can exit wreck")
	mission.recovery.response_seconds=.02
	check(mission.recovery.request(),"Survival uses the same recovery request")
	await collect_truck(mission.recovery)
	mission.pilot.global_position=mission.interaction.find_exit(mission.recovery.truck,2.5)
	await frames(3)
	check(mission.interaction.interact(),"Survival recovery uses ordinary truck interaction")
	await frames(200)
	check(game.encounters.stage==1 and game.encounters.active.map(func(a):return a.get_instance_id())==foes and not game.encounters.ended,"Recovery preserves Survival wave and actual enemy identities")
	# Fatal impact is an independent injury event, not an aircraft HP inference.
	check(mission.board_nearest(),"Board replacement for fatal-impact fixture")
	mission.occupied.impact_assessed.emit({"severity":4.0,"ignition":false})
	await frames(3)
	check(mission.pilot.health.hp==0 and game.encounters.ended and mission.survival.death_panel.visible,"Severe impact kills pilot and invokes one shared death flow")
	check(not mission.recovery.request() and not mission.leave_aircraft(),"Dead pilot cannot request transport or exit/board")
	await ready_game("interception")
	mission=game.malta_mission
	aircraft=await disable_nearby()
	check(game.interception.phase=="CHECKPOINT" and game.interception.elapsed==0,"Airframe loss does not fail/checkpoint-activate authored interception")
	check(mission.leave_aircraft(),"Mission survivor exits wreck")
	game.interception.phase="ACTIVE";game.interception.countdown_started=true
	var elapsed: float=game.interception.elapsed
	mission.recovery.response_seconds=.02;mission.recovery.request()
	await collect_truck(mission.recovery)
	check(game.interception.elapsed>elapsed and game.interception.phase=="ACTIVE","Mission countdown continues while recovery truck responds")
	mission.pilot.take_damage(1000)
	await frames(4)
	check(game.interception.phase=="FAILED" and game.interception.final_reason.contains("Pilot killed"),"Pilot death still immediately fails interception")
	check(mission.recovery.truck==null and mission.world.trucks.size()==3,"Pilot death cancels active recovery and removes temporary transport")
	for mode in ["harbour","aa_defence"]:
		await ready_game(mode)
		mission=game.malta_mission
		aircraft=await disable_nearby()
		var director: Node=game.harbour if mode=="harbour" else game.aa_defence
		var phase: String=director.phase
		var wave: int=director.wave
		var identity:=mission.world.get_instance_id()
		check(mission.leave_aircraft(),mode+": living operator can leave a lost aircraft")
		mission.recovery.response_seconds=.02
		check(mission.recovery.request(),mode+": shared assistance is available")
		await collect_truck(mission.recovery)
		mission.pilot.global_position=mission.interaction.find_exit(mission.recovery.truck,2.5)
		await frames(3)
		check(mission.interaction.interact(),mode+": explicit truck interaction starts return")
		await frames(200)
		check(director.phase==phase and director.wave==wave and mission.world.get_instance_id()==identity and aircraft.health.hp==0,mode+": recovery preserves objectives, wave and wreck rather than restarting")
		check(mission.nearest_serviceable()!=null,mode+": serviceable replacement remains accessible")
	await ready_game()
	mission=game.malta_mission
	check(mission.board_nearest(),"Board for actual low-speed sea-crash fixture")
	aircraft=mission.occupied
	aircraft.request_reset()
	aircraft.pending_reset_pose=Transform3D(Basis.IDENTITY,Vector3(50000,4,50000))
	aircraft.pending_reset_velocity=Vector3(0,-3,0)
	await frames(5)
	aircraft.engine_running=false
	for i in 480:
		await physics_frame
		if aircraft.impact_effects.water:break
	check(aircraft.impact_effects.water and aircraft.is_destroyed and mission.survival.alive(),"Actual gentle sea impact sinks the aircraft while pilot survives")
	check(mission.leave_aircraft(),"Pilot exits sinking sea wreck into water rather than remaining trapped")
	await frames(20)
	check(mission.pilot.swimming,"On-foot controller supports swimming at the sea surface")
	mission.recovery.response_seconds=.02
	check(mission.recovery.request(),"Sea survivor can call transport")
	await collect_truck(mission.recovery)
	check(mission.recovery.pontoon!=null and mission.recovery.truck.global_position.y>0,"Sea pickup truck is supported above water on a rescue pontoon")
	var sea_origin:=mission.pilot.global_position
	Input.action_press("throttle_up")
	for tick in 1800:
		var delta_position: Vector3=mission.recovery.truck.global_position-mission.pilot.global_position
		mission.pilot.yaw=atan2(-delta_position.x,-delta_position.z)
		await physics_frame
		if mission.pilot.global_position.distance_to(mission.recovery.truck.global_position+Vector3.UP)<4.1:break
	Input.action_release("throttle_up")
	check(mission.pilot.global_position.distance_to(sea_origin)>5 and mission.interaction.nearest()==mission.recovery.truck,"Real swimming controls reach the rescue pickup interaction")
	check(mission.interaction.interact(),"Explicit nearby truck entry, not arrival, returns the sea survivor")
	await frames(200)
	check(mission.recovery.returns==1 and mission.recovery.pontoon==null and mission.pilot.active and mission.nearest_serviceable()!=null,"Sea recovery cleans up pontoon/truck and restores access to a replacement")
	# Explosion/fire injury remains independent from hull HP and can be fatal.
	check(mission.board_nearest(),"Board replacement for cockpit-fire exposure")
	mission.occupied.components.ignite(&"engine")
	for i in 2400:
		await physics_frame
		if not mission.survival.alive():break
	check(not mission.survival.alive() and game.encounters.ended,"Sustained aircraft fire can still kill the independently healthy pilot")
	game.queue_free();await frames(10)
	print("PILOT RECOVERY RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)
