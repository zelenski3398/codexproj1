extends SceneTree
var passed:=0
var failed:=0
# Headless has no pointer lock; both actions feed the same existing trigger path.
var fire_action: String="fire" if DisplayServer.get_name()=="headless" else "aa_fire"
func _initialize() -> void:call_deferred("run")
func frames(n: int=4) -> void:
	for i in n:await physics_frame
func check(ok: bool,label: String) -> void:
	if ok:passed+=1;print("PASS: ",label)
	else:failed+=1;push_error("FAIL: "+label)
func aim(post: BoforsCommandPost,point: Vector3) -> void:
	var local: Vector3=post.global_basis.inverse()*(point-post.yaw.global_position)
	post.yaw.rotation.y=atan2(-local.x,-local.z)
	post.elevation.rotation.x=atan2(local.y,Vector2(local.x,local.z).length())
	post.mouse_controls.reset_target()
func shots(post: BoforsCommandPost) -> int:
	var count:=0
	for gun in post.battery_guns:count+=gun.shots_fired
	return count
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.start_free_roam("spitfire");await frames(25)
	var mission: MaltaMission=game.malta_mission
	var post: BoforsCommandPost=game.field.aa_battery.bofors_posts.filter(func(p):return p.field_id==mission.home)[0]
	mission.pilot.global_position=post.to_global(Vector3(0,1.05,3.5));await frames()
	check(mission.interaction.mount_gun(post),"Enter Bofors post through normal nearby interaction")
	check(post.battery_guns.all(func(g):return g.command_station==post),"Connected guns accept this occupied post as their controller")
	var point: Vector3=post.global_position-post.global_basis.z*800+Vector3.UP*350
	aim(post,point);await frames(250)
	check(shots(post)==0 and not post.battery_aim_assist,"Default manual sight laying never fires without player trigger")
	check("Fire battery" in game.gameplay_hud.actions.text and "Assist off" in game.gameplay_hud.actions.text,"Compact HUD exposes firing and assist toggle")
	Input.action_press(fire_action);await frames(180);Input.action_release(fire_action);await frames()
	check(post.battery_guns.all(func(g):return g.shots_fired>=2),"Holding LMB fires physical rounds from both connected Bofors")
	check(post.battery_guns.all(func(g):return g.shots_fired<=4 and is_equal_approx(g.weapon.reload_seconds,.5)),"Every gun retains its two-round-per-second reload")
	var before:=shots(post);await frames(120)
	check(shots(post)==before and post.orders.is_empty(),"Releasing trigger immediately cancels further rounds")
	var other_before: int=post.battery_guns[1].shots_fired
	var first_before: int=post.battery_guns[0].shots_fired
	post.gun_scope=1;await frames();Input.action_press(fire_action);await frames(150);Input.action_release(fire_action);await frames()
	check(post.battery_guns[0].shots_fired>first_before and post.battery_guns[1].shots_fired==other_before,"Individual scope leaves the other gun silent")
	var event:=InputEventKey.new();event.physical_keycode=KEY_B;event.pressed=true;Input.parse_input_event(event);await frames()
	event=InputEventKey.new();event.physical_keycode=KEY_B;Input.parse_input_event(event);await frames()
	check(post.battery_aim_assist and "Assist on" in game.gameplay_hud.actions.text,"B toggles measured predictive aim assistance on")
	before=shots(post);Input.action_press(fire_action);await frames(90);Input.action_release(fire_action);await frames()
	check(shots(post)==before,"Assisted mode cannot shoot without a valid assigned target")
	var foe:=EnemyAircraft.new();game.add_child(foe);await frames()
	foe.reset_pending=false;foe.freeze=true;foe.ai.set_physics_process(false);foe.set_physics_process(false)
	foe.global_position=point;post.measurement_error_metres=0
	aim(post,point);post.designate(foe);post.gun_scope=0;post.assign_target();await frames(360)
	check(post.battery_guns.all(func(g):return not post.command_solution(g).is_empty()),"Assigned observed enemy produces individual measured ballistic lead solutions")
	check(shots(post)==before,"Target assignment and assisted tracking alone do not fire")
	Input.action_press(fire_action);await frames(150);Input.action_release(fire_action);await frames()
	check(shots(post)>before,"Player-held trigger fires the assisted battery")
	before=shots(post);game.gameplay_hud.open_help();Input.action_press(fire_action);await frames(60)
	check(shots(post)==before,"Help pauses and suppresses battery firing")
	game.gameplay_hud.close_help();await frames(40)
	check(shots(post)==before,"Closing Help cannot replay a held trigger")
	post.toggle_battery_assist();await frames();check(not post.battery_aim_assist,"Aim assist can be switched off again")
	mission.interaction.leave_gun();before=shots(post);Input.action_press(fire_action);await frames(90);Input.action_release(fire_action)
	check(shots(post)==before and post.battery_guns.all(func(g):return g.command_station==null),"Dismount disconnects guns and leaves no autonomous fire")
	mission.pilot.global_position=post.to_global(Vector3(0,1.05,3.5));await frames();mission.interaction.mount_gun(post)
	post.battery_guns[1].take_damage(1000)
	await frames(8);aim(post,point);await frames(180)
	var lost_before: int=post.battery_guns[1].shots_fired
	Input.action_press(fire_action);await frames(120);Input.action_release(fire_action);await frames()
	check(post.battery_guns[1].shots_fired==lost_before,"Destroyed connected gun cannot participate in battery fire")
	var gun_health: Array=[]
	for g in post.battery_guns:gun_health.append(g.hp)
	post.take_damage(1000);await frames()
	check(not post.mounted and mission.interaction.occupied_gun==null and post.battery_guns.all(func(g):return g.command_station==null),"Post destruction cancels connected control")
	check(post.battery_guns.map(func(g):return g.hp)==gun_health,"Post destruction preserves each gun’s independent damage")
	game.show_selection(false);game.start_aa_defence();await frames(25)
	mission=game.malta_mission
	post=game.field.aa_battery.bofors_posts.filter(func(p):return p.field_id==mission.home)[0]
	mission.pilot.global_position=post.to_global(Vector3(0,1.05,3.5));await frames();mission.interaction.mount_gun(post)
	aim(post,post.global_position-post.global_basis.z*800+Vector3.UP*350);await frames(250)
	Input.action_press(fire_action);await frames(90)
	game.aa_defence._finish(false,"Battery control test")
	await frames();before=shots(post);await frames(90);Input.action_release(fire_action)
	check(shots(post)==before and post.orders.is_empty(),"Mission end stops a held battery trigger")
	game.restart_malta();await frames(25)
	check(game.field.aa_battery.bofors_posts.all(func(p):return not p.mounted and not p.battery_aim_assist and p.orders.is_empty() and p.battery_guns.all(func(g):return g.command_station==null and g.shots_fired==0)),"Retry creates fresh idle posts and guns with assist off")
	game.show_selection(false);game.queue_free();await frames()
	print("BOFORS BATTERY FIRE RESULT: %d/%d passed"%[passed,passed+failed]);quit(1 if failed else 0)
