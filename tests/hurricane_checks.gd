extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func frames(n: int=4) -> void:
	for i in n:await physics_frame
func check(ok: bool,label: String) -> void:
	if ok:passed+=1;print("PASS: ",label)
	else:failed+=1;push_error("FAIL: "+label)
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	var game=load("res://main.tscn").instantiate();root.add_child(game);await frames()
	check(game.selector.buttons.size()==3,"Main menu offers three Allied fighters")
	game.selector.select("hurricane");await frames()
	check(game.selector.preview is HurricaneModel and "Merlin III" in game.selector.details.text,"Hurricane selection owns its distinct Mk I model and description")
	game.selector._fly();await frames(200)
	var mission: MaltaMission=game.malta_mission
	var plane: HawkerHurricane=mission.initial_aircraft
	check(game.game_mode=="encounter" and game.environment_id=="malta" and plane!=null,"Normal menu Fly launches Hurricane Malta free roam")
	check(mission.fleet.size()==9 and mission.fleet.filter(func(a):return a is HawkerHurricane).size()==3,"Exactly one Hurricane per airfield in peaceful free roam")
	check(mission.fleet.filter(func(a):return a is HawkerHurricane).all(func(a):return a.health.hp==100 and a.gear.contact_count==3 and a.airspeed<.3 and not a.engine_running),"All three bases support a healthy, stopped Hurricane on three wheels")
	var clear_hangars: bool=true
	for fighter in mission.fleet.filter(func(a):return a is HawkerHurricane):
		var inside: bool=false
		for field in mission.world.fields.values():
			for building in field.installations:
				if not building is AircraftHangar:continue
				var origin: Vector3=building.to_local(fighter.global_position)
				if absf(origin.x)>24 or absf(origin.z)>18:continue
				inside=true
				for mesh in fighter.model.find_children("*","MeshInstance3D",true,false):
					if not mesh.is_visible_in_tree():continue
					var bounds: AABB=mesh.get_aabb()
					for corner in 8:
						var point: Vector3=building.to_local(mesh.to_global(bounds.get_endpoint(corner)))
						clear_hangars=clear_hangars and absf(point.x)<building.width*.5-.1 and absf(point.z)<building.depth*.5-.1 and point.y<building.entrance_height-.1
		clear_hangars=clear_hangars and inside
	check(clear_hangars,"All visible Hurricane mesh bounds clear their hangar walls, rear and entrance height")
	check(mission.nearest_serviceable()==plane and mission.pilot.active and not plane.engine_running,"On-foot player starts beside the selected stopped Hurricane")
	check(plane.gear.contact_count==3 and plane.airspeed<.3 and plane.health.hp==100,"Hurricane settles on all three wheels without hangar collision damage")
	check(plane.team_id==CombatTeams.PLAYER and plane.guns.firing_ports.size()==8,"Allied identification and eight physical .303 muzzle markers")
	var model: HurricaneModel=plane.model
	var min_x: float=INF;var max_x: float=-INF
	for mesh in model.get_children():
		if mesh is MeshInstance3D and mesh.name in ["LeftWing","RightWing"]:
			min_x=minf(min_x,mesh.get_aabb().position.x);max_x=maxf(max_x,mesh.get_aabb().end.x)
	check(absf((max_x-min_x)-12.19)<.01,"Original rounded/tapered wing mesh spans 12.19 metres")
	check(model.ailerons.size()==2 and model.elevators.size()==2 and model.rudder!=null and model.propeller.get_child_count()==4,"Separate control surfaces and three-bladed propeller")
	for side in [-1,1]:
		check(model.gun_ports.filter(func(p):return signf(p.position.x)==side and p.position.z<-.9).size()==4,"Four flush wing ports on side "+str(side))
	check(plane.wing_area==23.92 and plane.mass==2994 and plane.engine_thrust>8500 and plane.engine_thrust<12500,"Distinct editable flight baseline between Gladiator and Spitfire power")
	check(plane.components.definitions.size()>=12 and plane.components.profile==load("res://damage_profiles/hurricane_mk_i.tres"),"Hurricane-specific component hitboxes reuse universal damage")
	check("Enter aircraft" in game.gameplay_hud.actions.text and mission.board_nearest(),"Existing contextual prompt boards the exact selected aircraft")
	await frames();check(not "Enter aircraft" in game.gameplay_hud.actions.text and game.selected_aircraft=="hurricane","Boarding clears entry prompt and preserves Hurricane identity")
	var event:=InputEventKey.new();event.physical_keycode=KEY_I;event.pressed=true;Input.parse_input_event(event);await frames()
	event=InputEventKey.new();event.physical_keycode=KEY_I;Input.parse_input_event(event);await frames()
	check(plane.engine_running and plane.pilot.throttle==0,"Existing I control manually starts the engine at idle")
	plane.engine_running=false
	check(mission.leave_aircraft(),"Stopped Hurricane supports normal exit")
	var world_id: int=game.field.get_instance_id()
	check(mission.board_aircraft(plane),"Re-enter Hurricane without creating a new aircraft")
	# Explicit open-ground loss fixture isolates recovery from flying a crash route.
	plane.request_reset();plane.pending_reset_pose=mission.world.fields[mission.home].global_transform*Transform3D(Basis(Vector3.RIGHT,.117),Vector3(-120,1.18,100))
	await frames(12);plane.pilot.automated=true;plane.pilot.brakes=true
	plane.take_damage(1000);await frames();mission.leave_aircraft();await frames()
	check(mission.survival.alive() and plane.is_destroyed and not game.encounters.ended,"Aircraft loss preserves independent surviving pilot")
	check(mission.safe_base_point(mission.home).is_finite() and mission.serviceable_count(mission.home)==2,"Existing replacement/recovery selects other serviceable airframes")
	mission.recovery.response_seconds=.02;check(mission.recovery.request(),"Surviving Hurricane pilot can request recovery transport")
	for i in 1200:
		await physics_frame
		if mission.recovery.state=="READY":break
	check(mission.recovery.state=="READY" and is_instance_valid(mission.recovery.truck),"Shared recovery truck reaches a usable pickup")
	mission.pilot.global_position=mission.interaction.find_exit(mission.recovery.truck,2.5);await frames()
	check(mission.interaction.interact(),"Pilot enters the real recovery truck")
	await frames(200)
	check(mission.recovery.returns==1 and game.field.get_instance_id()==world_id and mission.fleet.size()==9 and mission.nearest_serviceable()!=null,"Recovery preserves world and damaged fleet without duplicate Hurricanes")
	game.restart_malta();await frames(200)
	check(game.malta_mission.initial_aircraft is HawkerHurricane and game.malta_mission.fleet.size()==9,"Full retry restores selected Hurricane and exactly one fresh roster")
	game.show_selection(false);game.start_harbour();await frames(30)
	check(game.malta_mission.fleet.size()==7 and game.malta_mission.fleet.all(func(a):return not a is HawkerHurricane),"Scripted Faith/Hope/Charity roster remains unchanged")
	game.show_selection(false);game.queue_free();await frames()
	print("HURRICANE RESULT: %d/%d passed"%[passed,passed+failed]);quit(1 if failed else 0)
