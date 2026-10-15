extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in range(n):await physics_frame
func check(ok: bool,label: String) -> void:
	if ok:passed+=1;print("PASS: ",label)
	else:failed+=1;push_error("FAIL: "+label)
func run() -> void:
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	game.start_aa_defence()
	await frames(20)
	game.aa_defence.set_physics_process(false)
	var station: AACommandStation
	for post in game.field.aa_battery.command_stations:
		if post.field_id=="luqa":station=post
	var interaction: AirfieldInteraction=game.malta_mission.interaction
	game.malta_mission.pilot.global_position=interaction.find_exit(station,3)
	await frames(2)
	var enter:=InputEventKey.new()
	enter.keycode=KEY_F
	enter.physical_keycode=KEY_F
	enter.pressed=true
	Input.parse_input_event(enter)
	await frames(4)
	enter=InputEventKey.new()
	enter.keycode=KEY_F
	enter.physical_keycode=KEY_F
	Input.parse_input_event(enter)
	await frames(4)
	check(station.mounted and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"F enters staffed predictor camera with actual desktop mouse capture")
	var foe:=EnemyAircraft.new()
	game.add_child(foe)
	foe.freeze=true
	foe.reset_pending=false
	foe.ai.set_physics_process(false)
	foe.rear_gunner.set_physics_process(false)
	foe.global_position=station.global_position+station.global_basis*Vector3(0,500,-1500)
	await frames(3)
	var motion:=InputEventMouseMotion.new()
	motion.screen_relative=Vector2(0,-rad_to_deg(atan2(500.0,1500.0))/station.weapon.mouse_degrees_per_pixel/AAMouseControls.sensitivity)
	motion.relative=motion.screen_relative
	Input.parse_input_event(motion)
	await frames(90)
	check(not station.designated,"Mouse looking alone never automatically selects a target")
	var button:=InputEventMouseButton.new()
	button.button_index=MOUSE_BUTTON_RIGHT
	button.pressed=true
	Input.parse_input_event(button)
	await frames(4)
	button=InputEventMouseButton.new()
	button.button_index=MOUSE_BUTTON_RIGHT
	Input.parse_input_event(button)
	await frames(8)
	check(station.target==foe and station.designated,"Actual RMB sight designation selects the visible hostile aircraft")
	check(station.salvos_issued==0 and station.battery.projectiles.total_spawned==0,"RMB designation and tracking cannot start firing")
	button=InputEventMouseButton.new()
	button.button_index=MOUSE_BUTTON_LEFT
	button.pressed=true
	Input.parse_input_event(button)
	await frames(180)
	button=InputEventMouseButton.new()
	button.button_index=MOUSE_BUTTON_LEFT
	Input.parse_input_event(button)
	check(station.salvos_issued==1 and station.commanded_shots==4,"Actual LMB orders exactly one staggered four-gun salvo")
	check(station.marker.visible and "4/4 OPERATIONAL" in station.status_text(),"Gunner view displays predicted intercept and live battery status")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/previews/aa-battery-command.png")
	game.malta_mission.chart_panel.show()
	await process_frame
	await process_frame
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and station.orders.is_empty(),"Opening map releases cursor and cancels outstanding firing orders")
	game.malta_mission.chart_panel.hide()
	interaction.leave_gun()
	check(game.malta_mission.pilot.active and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Dismount restores original walking camera and cursor")
	print("BATTERY UI RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)
