extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func frames(n: int=4) -> void:
	for i in n:await physics_frame
func check(value: bool,label: String) -> void:
	if value:passed+=1;print("PASS: ",label)
	else:failed+=1;push_error("FAIL: "+label)
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.start_aa_defence();await frames(30)
	var mission: MaltaMission=game.malta_mission
	var controls: AirfieldInteraction=mission.interaction
	var ui: GameplayHUD=game.gameplay_hud
	var director: DiveDefenceMission=game.aa_defence
	var gun: BritishAAGun=director.guns[0]
	mission.pilot.global_position=controls.find_exit(gun,5);await frames()
	check("Mount AA gun" in ui.actions.text and ui.objective.text=="Mount an AA gun","Nearby entry prompt and concise initial objective")
	check(controls.mount_gun(gun),"Mount AA gun")
	# Context is derived synchronously, without waiting for the next HUD frame.
	check("Exit gun" in controls.prompt() and not "Mount" in controls.prompt(),"Mount clears entry text immediately in shared presenter")
	await frames()
	check(ui.objective.text=="Defend the position" and not director.marker.visible and not director.objective.visible,"Mounted objective updates; legacy instructions and navigation marker hidden")
	check(not ui.notification.visible or not "Mouse aims" in ui.notification.text,"No long mounting notification")
	check(not gun.get_node("FriendlyAALabel").visible,"Equipment world caption cannot overlap mounted HUD")
	var recovery_state: String=mission.recovery.state
	mission.recovery.state="ARRIVING"
	check(not "Transport" in ui.context_actions(),"Mounted actions suppress unrelated transport prompts")
	mission.recovery.state=recovery_state
	var camera:=root.get_camera_3d();var yaw:=gun.yaw.rotation.y;var shots:=gun.shots_fired;var clock:=director.clock
	ui.open_help();Input.action_press("aa_fire");Input.action_press("roll_left");await frames(12)
	check(paused and director.clock==clock and gun.shots_fired==shots and gun.yaw.rotation.y==yaw,"Mounted help pauses wave timer, traverse and firing")
	Input.action_release("roll_left");ui.close_help();await frames()
	check(not paused and root.get_camera_3d()==camera and not Input.is_action_pressed("aa_fire"),"Help restores camera and clears held fire")
	check(controls.leave_gun(),"Dismount")
	await frames();check("Mount AA gun" in ui.actions.text,"Eligible nearby gun prompt returns")
	mission.pilot.global_position+=Vector3(400,0,400);await frames()
	check(not "Mount" in ui.actions.text and not "Enter" in ui.actions.text,"No entry prompt outside interaction range")
	var truck: MilitaryTruck=mission.world.trucks[1]
	mission.pilot.global_position=truck.global_position+Vector3(2,1,0);await frames()
	check("Enter truck" in ui.actions.text and controls.enter_vehicle(truck),"Truck entry prompt and mounting")
	var phase_before: String=director.phase
	director.phase="WAIT_MOUNT";ui.update_objective()
	check(ui.objective.text=="Mount an AA gun","Driving before the first mount does not complete the gun objective")
	director.phase=phase_before
	await frames();check(not "Enter" in ui.actions.text and not "Mount" in ui.actions.text and not director.marker.visible,"Driving suppresses nearby gun and vehicle entry instructions")
	ui.open_help();await frames();ui.close_help();await frames()
	check(controls.occupied_vehicle==truck and root.get_camera_3d()==truck.camera,"Truck help retains occupied controller and camera")
	check(controls.leave_vehicle(),"Exit vehicle")
	mission.pilot.global_position=controls.find_exit(gun,5);await frames();check(controls.mount_gun(gun),"Switch back to gun")
	gun.take_damage(10000);await frames()
	check(controls.occupied_gun==null and not "Exit gun" in ui.actions.text and not "Mount AA gun" in ui.actions.text,"Occupied destruction clears stale gun instructions")
	# Model recovery relocation without changing battle state.
	mission.pilot.global_position=mission.world.fields[mission.home].pilot_spawn;await frames()
	check(ui.actions.text==ui.context_actions() and not "Exit gun" in ui.actions.text,"Relocation reacquires only currently eligible context")
	for phase in ["ACTIVE","DRAINING","INTERVAL"]:
		director.phase=phase;director.wave=3;director.clock=100;await frames(1)
		check(ui.objective.text=="Defend the position" and ui.supporting.text.count("\n")==1,"Concise objective and counters: "+phase)
	paused=true;ui.open_help();ui.close_help();await frames()
	check(paused and ui.pause_panel.visible,"Pause-menu help restores paused state")
	paused=false
	mission.pilot.health.take_damage(100);await frames()
	check(ui.actions.text.is_empty() and not ui.notification.visible and controls.nearest()==null,"Death and mission failure clear interaction text and notices")
	check("aim estimate" in ui.controls_text() and "transport" in ui.controls_text() and GameplayHUD.binding("controls_help")=="F1","Help uses actual bindings and explains aim estimate and recovery")
	game.show_selection(false);await frames();check(not ui.root.visible,"Mission exit removes HUD")
	game.queue_free();await frames()
	print("AA HUD CONTEXT RESULT: %d/%d passed"%[passed,passed+failed]);quit(1 if failed else 0)
