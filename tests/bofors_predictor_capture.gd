extends SceneTree
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await physics_frame
func capture(name: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/"+name+".png")
	print("CAPTURE: ",name)
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.start_malta("luqa","spitfire");await frames(20)
	var mission: MaltaMission=game.malta_mission
	var posts: Array=game.field.aa_battery.bofors_posts
	var post: BoforsCommandPost=posts.filter(func(p):return p.field_id=="luqa")[0]
	mission.canvas.hide();GameAudioMixer.instance.audio_button.hide()
	var view:=Camera3D.new();view.far=12000;view.fov=58;game.add_child(view);view.make_current()
	view.global_position=post.to_global(Vector3(7,4,8));view.look_at(post.global_position+Vector3.UP*1.3)
	await frames(8);await capture("bofors-predictor-post")
	var fort: BoforsCommandPost=posts.filter(func(p):return p.field_id=="st_elmo")[0]
	view.global_position=fort.to_global(Vector3(7,5,9));view.look_at(fort.global_position+Vector3.UP*1.1)
	await frames(8);await capture("bofors-predictor-st-elmo")
	mission.canvas.show()
	mission.pilot.global_position=post.to_global(Vector3(0,1.05,3.5));await frames(3)
	mission.interaction.mount_gun(post)
	var foe:=EnemyAircraft.new();game.add_child(foe);await frames(3)
	foe.freeze=true;foe.reset_pending=false;foe.ai.set_physics_process(false);foe.set_physics_process(false)
	foe.global_position=post.global_position-post.global_basis.z*650+Vector3.UP*180
	var local: Vector3=post.global_basis.inverse()*(foe.global_position-post.yaw.global_position)
	post.yaw.rotation.y=atan2(-local.x,-local.z);post.elevation.rotation.x=atan2(local.y,Vector2(local.x,local.z).length());post.mouse_controls.reset_target()
	post.measurement_error_metres=0;post.designate(foe);post.assign_target()
	Input.action_press("aa_zoom");await frames(260);await capture("bofors-predictor-optics");Input.action_release("aa_zoom")
	mission.interaction.leave_gun()
	var gun: BritishAAGun=post.battery_guns[0]
	mission.pilot.global_position=mission.interaction.find_exit(gun,5);await frames(3);mission.interaction.mount_gun(gun)
	var previous_mode:=AAMouseControls.fire_control_mode
	AAMouseControls.set_fire_control_mode(2)
	var solution: Dictionary
	for i in 3:
		post.update_solutions(.12);solution=post.get_solution(gun)
		gun.yaw.rotation.y=solution.yaw;gun.elevation.rotation.x=solution.pitch
	gun.yaw.rotation.y-=deg_to_rad(2.5);gun.elevation.rotation.x-=deg_to_rad(.5);gun.mouse_controls.reset_target()
	await frames(10);await capture("bofors-predictor-training")
	var sight: AAAimReticle=mission.interaction.sight
	assert(sight.marker_visible and not sight.aligned,"Training sight must draw a separate unaligned lead diamond")
	for i in 3:
		post.update_solutions(.12);solution=post.get_solution(gun);gun.yaw.rotation.y=solution.yaw;gun.elevation.rotation.x=solution.pitch
	gun.mouse_controls.reset_target();await frames(8);await RenderingServer.frame_post_draw
	assert(sight.marker_visible and sight.aligned,"Manually aligned sight must report on target")
	print("BOFORS RENDER RESULT: 2/2 passed")
	AAMouseControls.set_fire_control_mode(previous_mode)
	AircraftImpactService.obtain().clear_all();game.queue_free();await frames(10);quit()
