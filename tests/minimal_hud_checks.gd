extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func frames(count: int=3) -> void:
	for i in count:await process_frame
func check(ok: bool,text: String) -> void:
	if ok:passed+=1
	else:failed+=1
	print("PASS: " if ok else "FAIL: ",text)
func key(code: Key) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event);await frames()
	event=InputEventKey.new();event.physical_keycode=code;Input.parse_input_event(event);await frames()
func help_roundtrip(game: Node,label: String) -> void:
	var ui: GameplayHUD=game.gameplay_hud
	var camera:=root.get_camera_3d()
	await key(KEY_F1)
	check(ui.help_open and paused and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,label+": F1 opens help and pauses")
	var position: Vector3=game.malta_mission.pilot.global_position
	var gun=game.malta_mission.interaction.occupied_gun
	var aircraft=game.malta_mission.occupied
	var truck=game.malta_mission.interaction.occupied_vehicle
	var aircraft_snapshot: Transform3D=game.malta_mission.occupied.global_transform if is_instance_valid(game.malta_mission.occupied) else Transform3D.IDENTITY
	await key(KEY_E);await key(KEY_F);await key(KEY_C);await key(KEY_I);await key(KEY_M);await key(KEY_V);await key(KEY_R)
	check(game.malta_mission.interaction.occupied_gun==gun and game.malta_mission.occupied==aircraft and game.malta_mission.interaction.occupied_vehicle==truck and position==game.malta_mission.pilot.global_position and not game.malta_mission.chart_panel.visible,label+": actions blocked behind help")
	check(not is_instance_valid(aircraft) or aircraft.global_transform==aircraft_snapshot,label+": aircraft transform unchanged during help")
	await key(KEY_ESCAPE)
	check(not ui.help_open and not paused and root.get_camera_3d()==camera,label+": Escape closes help first and preserves camera")
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.start_test_departure("sea_gladiator");await frames(50)
	var ui: GameplayHUD=game.gameplay_hud
	var mission: MaltaMission=game.malta_mission
	check(not ui.tracker.visible and not mission.status.visible and not ui.debug.visible,"Free roam has no empty mission tracker, legacy paragraphs or default diagnostics")
	check(ui.notification.text=="F1 — Controls","Brief initial help hint")
	for heading in ["On Foot","Aircraft","AA Guns","Vehicles","Radio","Recovery","General"]:check(heading in ui.controls_text(),"Help contains "+heading)
	check("T" in ui.controls_text() and "RMB" in ui.controls_text() and "approximate area" in ui.controls_text(),"Radio and actual right-click behaviours explained")
	check(GameplayHUD.binding("board")=="E" and GameplayHUD.binding("controls_help")=="F1","Bindings derive from InputMap")
	await help_roundtrip(game,"On foot")
	check(mission.board_nearest(),"Board grounded aircraft")
	await frames();check(not "Enter aircraft" in ui.actions.text and ui.parts.visible,"Board clears entry prompt; component health remains visible")
	await help_roundtrip(game,"Aircraft")
	# Explicit airborne fixture isolates help from the unrelated takeoff sequence.
	var parked: Transform3D=mission.occupied.global_transform
	mission.occupied.global_position+=Vector3.UP*500
	mission.occupied.linear_velocity=Vector3.FORWARD*70
	await physics_frame
	await help_roundtrip(game,"Airborne aircraft")
	mission.occupied.global_transform=parked;mission.occupied.linear_velocity=Vector3.ZERO
	for i in 8:await physics_frame
	check(mission.leave_aircraft(),"Leave parked aircraft")
	await frames();check("Enter aircraft" in ui.actions.text,"Dismount reacquires nearby aircraft")
	var gun: BritishAAGun=mission.world.aa_battery.guns.filter(func(g):return not g.weapon.heavy and g.name.begins_with(mission.home))[0]
	mission.pilot.global_position=gun.global_position+Vector3(0,1,3);await frames()
	check(mission.interaction.mount_gun(gun),"Mount Bofors")
	await frames();check("Exit gun" in ui.actions.text and "Optics zoom" in ui.actions.text and not "Mount" in ui.actions.text,"Gun context suppresses nearby mount prompts")
	await help_roundtrip(game,"Bofors")
	check(mission.interaction.leave_gun(),"Dismount Bofors")
	var truck: MilitaryTruck=mission.world.trucks[0]
	mission.pilot.global_position=truck.global_position+Vector3(2,1,0);await frames()
	check(mission.interaction.enter_vehicle(truck),"Enter truck")
	await frames();check(not "Mount" in ui.actions.text and not "Enter" in ui.actions.text,"Truck suppresses world entry prompts")
	await help_roundtrip(game,"Truck")
	check(mission.interaction.leave_vehicle(),"Exit truck")
	await key(KEY_ESCAPE);check(paused and ui.pause_panel.visible,"Pause menu on foot")
	ui.open_help();ui.close_help();await frames();check(paused and ui.pause_panel.visible,"Help opened from pause restores previous pause state")
	await key(KEY_ESCAPE)
	mission.pilot.global_position+=Vector3(10000,0,10000);await frames();check(not "Enter aircraft" in ui.actions.text and not "Mount" in ui.actions.text,"Prompts clear outside interaction range")
	check("Call transport" in ui.actions.text,"Recovery hint appears only when transport is eligible")
	mission.pilot.health.take_damage(100);await frames();check(ui.actions.text=="" or not ui.actions.visible,"Dead pilot has no interaction prompts")
	game.show_selection(false);game.start_interception("spitfire");await frames(50)
	var interception: VallettaInterception=game.interception
	check(interception.definition.deadline_seconds==180 and interception.elapsed==0,"180-second deadline, timer stopped during navigation")
	check(ui.tracker.visible and "1/2" in ui.objective.text and not "2/2" in ui.objective.text,"Only current checkpoint shown in shared tracker")
	interception._advance_checkpoint(0);await frames();check("2/2" in ui.objective.text and ui.completion.visible,"Checkpoint advances once with completion cue")
	root.content_scale_size=Vector2i(960,600);root.size=Vector2i(960,600);await frames()
	check(not ui.tracker.get_global_rect().intersects(ui.vital.get_global_rect()),"Small window keeps health and objective separate")
	check(game.malta_mission.board_nearest(),"Board for activation fixture")
	game.aircraft.global_position=interception.current_checkpoint();interception.checkpoint_index=2;interception.activate();await frames(4)
	check(interception.phase=="ACTIVE" and interception.elapsed<1 and "03:00" in ui.supporting.text,"Existing final trigger starts displayed 03:00")
	var time: float=interception.elapsed;ui.open_help();await frames(20);check(interception.elapsed==time,"Help pauses actual mission timer");ui.close_help()
	check(interception.definition.approach_seconds==90 and (interception.bomber.ai as BomberPilot).route_duration==90,"Deadline extension preserves original physical bomber approach")
	for mode in ["survival","harbour","aa_defence"]:
		game.show_selection(false);game.start_malta("hal_far" if mode=="harbour" else "luqa","sea_gladiator" if mode=="harbour" else "spitfire",mode,false);await frames(30)
		check(ui.tracker.visible and not ui.objective.text.is_empty(),mode+": shared objective populated")
		check(ui.supporting.text.count("\n")<=2,mode+": at most three supporting lines")
	game.show_selection(false);await frames();check(not ui.root.visible,"HUD removed from menu")
	game.queue_free();await frames(10)
	print("MINIMAL HUD RESULT: %d/%d passed"%[passed,passed+failed]);quit(1 if failed else 0)
