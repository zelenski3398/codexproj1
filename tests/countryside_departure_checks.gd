extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await physics_frame
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failed+=1
	print("PASS: " if ok else "FAIL: ",label)
func run() -> void:
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.start_test_departure("sea_gladiator")
	await frames(180)
	var mission: MaltaMission=game.malta_mission
	check(game.field is CountrysideWorld and game.environment_id=="countryside" and mission.initial_aircraft is SeaGladiator,"Separate countryside option retains its terrain and selected aircraft")
	check(mission.fleet.size()==2 and mission.world.fields.size()==1 and get_nodes_in_group("aircraft_hangars").size()==3,"Countryside shares existing three hangars without duplicate terrain or structures")
	check(mission.pilot.active and mission.nearest_serviceable()==mission.initial_aircraft,"Test-map pilot starts beside selected aircraft inside hangar")
	check(mission.fleet.all(func(a):return not a.engine_running and a.gear.contact_count==3 and a.airspeed<.3),"Both available test-map aircraft remain parked and stopped")
	check(mission.board_nearest(),"Normal boarding uses shared controller on test map")
	mission.occupied.take_damage(1000)
	await frames(3)
	check(mission.survival.alive() and not game.encounters.ended and mission.leave_aircraft(),"Test-map pilot can survive and exit hull loss")
	mission.recovery.response_seconds=.02
	check(mission.recovery.request(),"Countryside uses the same assistance action")
	for i in 1200:
		await physics_frame
		if mission.recovery.state=="READY":break
	check(mission.recovery.truck!=null and mission.recovery.state=="READY","Recovery truck can find actual countryside terrain")
	mission.pilot.global_position=mission.interaction.find_exit(mission.recovery.truck,2.5)
	await frames(3)
	check(mission.interaction.interact(),"Test-map return requires actual truck interaction")
	await frames(200)
	check(mission.recovery.returns==1 and mission.nearest_serviceable()!=null and mission.world.trucks.size()==1,"Test-map recovery leaves replacement and one original truck")
	game.restart_malta();await frames(180)
	check(game.field is CountrysideWorld and game.malta_mission.pilot.health.hp==100 and game.malta_mission.fleet.size()==2,"Test-map full retry restores its own map, not Malta")
	game.show_selection(false);await frames(3)
	check(game.field is Airfield and game.selector!=null and game.malta_mission==null,"Test-map return releases persistent session cleanly")
	game.queue_free();await frames(5)
	print("COUNTRYSIDE DEPARTURE RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)
