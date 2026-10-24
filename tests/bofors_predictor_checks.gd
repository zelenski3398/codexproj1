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
func aim_post(post: BoforsCommandPost,point: Vector3) -> void:
	var local: Vector3=post.global_basis.inverse()*(point-post.yaw.global_position)
	post.yaw.rotation.y=atan2(-local.x,-local.z)
	post.elevation.rotation.x=atan2(local.y,Vector2(local.x,local.z).length())
	post.mouse_controls.reset_target()
func key(code: Key) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true
	Input.parse_input_event(event);await frames(3)
	event=InputEventKey.new();event.physical_keycode=code;Input.parse_input_event(event);await frames(2)
func move_target(unit: FlightAircraft,velocity: Vector3,ticks: int) -> void:
	for i in ticks:
		unit.global_position+=velocity/120
		await physics_frame
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.start_free_roam("spitfire");await frames(20)
	var battery: AirfieldAABattery=game.field.aa_battery
	check(battery.bofors_posts.size()==4,"One predictor at every airfield and Fort St Elmo")
	check(battery.command_stations.size()==3 and battery.guns.size()==18 and game.field.fort_battery.guns.size()==3,"Existing heavy commands and all 21 AA guns remain in place")
	var supported:=true
	var exposed:=true
	for post in battery.bofors_posts:
		check(post.battery_guns.size()==(3 if post.field_id=="st_elmo" else 2) and post.battery_guns.all(func(g):return not g.weapon.heavy and g.predictor_post==post),"Each post connects only its own existing Bofors battery")
		for offset in [Vector3.ZERO,Vector3(1.8,0,1.8),Vector3(-1.8,0,-1.8)]:
			var point: Vector3=post.to_global(offset)
			var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.1,point+Vector3.DOWN*1,1,[post.get_rid()])
			var hit:=post.get_world_3d().direct_space_state.intersect_ray(ray)
			supported=supported and not hit.is_empty() and hit.normal.y>.8
			var sky:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*2000,point+Vector3.DOWN*1,1,[post.get_rid()])
			var top:=post.get_world_3d().direct_space_state.intersect_ray(sky)
			exposed=exposed and not top.is_empty() and absf(top.position.y-point.y)<.15
	check(supported,"All four observation positions have terrain or fort-deck support")
	check(exposed,"Post floors are exposed sky-facing surfaces rather than terrain buried under a fort deck")
	check(battery.bofors_posts.all(func(p):return p.crew.get_parent()==p and is_zero_approx(p.crew.position.y)),"Observer personnel stand on the post floor rather than the elevated gunner seat")
	var mission: MaltaMission=game.malta_mission
	var fort_post: BoforsCommandPost=battery.bofors_posts.filter(func(p):return p.field_id=="st_elmo")[0]
	mission.pilot.global_position=StElmoLocations.position_for("st_elmo")
	var approach: Vector3=fort_post.to_global(Vector3(0,1.05,3.5))
	for tick in 1200:
		if mission.interaction.nearest_command()==fort_post:break
		var local: Vector3=Basis(Vector3.UP,mission.pilot.yaw).inverse()*(approach-mission.pilot.global_position)
		for action in ["rudder_left","rudder_right","throttle_up","throttle_down"]:Input.action_release(action)
		if absf(local.x)>.2:Input.action_press("rudder_right" if local.x>0 else "rudder_left")
		if absf(local.z)>.2:Input.action_press("throttle_down" if local.z>0 else "throttle_up")
		await physics_frame
	for action in ["rudder_left","rudder_right","throttle_up","throttle_down"]:Input.action_release(action)
	check(mission.interaction.nearest_command()==fort_post and absf(mission.pilot.global_position.y-approach.y)<.3,"Actual walking inputs reach the exposed predictor from the original St Elmo spawn")
	for site in battery.bofors_posts:
		mission.pilot.global_position=site.to_global(Vector3(0,1.05,3.5));await frames(3)
		check(mission.interaction.mount_gun(site) and mission.interaction.leave_gun(),"Each airfield/fort post supports nearby mounting and a safe walkable dismount")
	var post: BoforsCommandPost=battery.bofors_posts.filter(func(p):return p.field_id==mission.home)[0]
	var gun: BritishAAGun=post.battery_guns[0]
	post.measurement_error_metres=0
	mission.pilot.global_position=post.to_global(Vector3(0,1.05,3.5));await frames(3)
	check(mission.interaction.nearest_command()==post and mission.interaction.prompt().contains("Bofors Predictor"),"Nearby soldier sees the Bofors predictor interaction")
	await key(KEY_F)
	check(mission.interaction.occupied_gun==post and post.mounted and post.camera.current and not mission.pilot.active,"F enters optics through exclusive existing controller routing")
	var foe:=EnemyAircraft.new();game.add_child(foe);await frames(3)
	foe.reset_pending=false;foe.freeze=true;foe.ai.set_physics_process(false);foe.set_physics_process(false)
	foe.global_position=post.global_position-post.global_basis.z*650+Vector3.UP*180
	aim_post(post,foe.global_position);await frames(3)
	foe.team_id=CombatTeams.PLAYER;post.designate(foe)
	check(post.target==null,"Friendly aircraft cannot be designated")
	foe.team_id=CombatTeams.ENEMY
	var hidden:=EnemyAircraft.new();game.add_child(hidden);await frames(2)
	hidden.reset_pending=false;hidden.freeze=true;hidden.ai.set_physics_process(false);hidden.set_physics_process(false)
	hidden.global_position=post.global_position+post.global_basis.x*900+Vector3.UP*180
	game.encounters.track_enemy(hidden);await frames(3)
	post.scan_visible_targets()
	check(post.detected.has(foe) and not post.detected.has(hidden),"Optics reveal only visible aircraft within the observation cone")
	check(not game.encounters.enemy_widgets[hidden.get_instance_id()].visible,"Predictor optics suppress the ordinary omnidirectional enemy HUD labels")
	post.designate(foe);await key(KEY_ENTER);await frames(300)
	check(post.target==foe and post.assigned_guns.size()==2,"Player explicitly assigns the observed target to the whole battery")
	check(post.quality>.65 and post.ready_announced,"Stationary observation stabilizes and announces predictor readiness")
	check(mission.chart.contacts.size()==1 and mission.chart.contacts[0].position.distance_to(post.observed_position)<1,"Observer navigation chart contains the measured contact only")
	check(post.report.contains("AMSL") and post.report.contains("HDG") and post.report.contains("yd"),"Estimated range, altitude and heading appear with period range units")
	var solution: Dictionary=post.get_solution(gun)
	check(not solution.is_empty() and solution.valid,"Stationary target inside the gun envelope produces a valid solution")
	if not solution.is_empty():
		var flight: Vector3=gun.muzzle.global_position+solution.direction*gun.projectile_speed*solution.time+Vector3.DOWN*.5*battery.light_projectiles.gravity*solution.time*solution.time
		check(flight.distance_to(solution.point)<.01 and solution.aim_point.y>solution.point.y,"Lead marker compensates gravity and agrees with the real shell ballistic equation")
	var other: Dictionary=post.get_solution(post.battery_guns[1])
	check(not other.is_empty() and absf(other.time-solution.get("time",0))>.02,"Separated Bofors positions receive distinct travel-time solutions")
	await move_target(foe,post.global_basis.x*60,360)
	solution=post.get_solution(gun)
	check(not solution.is_empty() and (solution.point-post.observed_position).dot(post.observed_velocity)>0 and post.observed_velocity.length()>50,"Moving observations estimate velocity and put the intercept ahead of the aircraft")
	var stable: float=post.quality
	await move_target(foe,-post.global_basis.x*100,30)
	check(post.quality<stable*.7,"A sharp reversal temporarily reduces predictor confidence")
	await move_target(foe,Vector3.ZERO,400)
	aim_post(post,foe.global_position)
	post.gun_scope=1;post.assign_target()
	check(post.assigned_guns==[gun] and post.get_solution(post.battery_guns[1]).is_empty(),"Individual-gun assignment leaves other Bofors without a predictive sight")
	post.gun_scope=0;post.assign_target()
	check(post.assigned_guns.size()==2,"Common battery assignment restores both individual solutions")
	var saved_position: Vector3=foe.global_position
	foe.global_position=post.global_position-post.global_basis.z*3300+Vector3.UP*500
	aim_post(post,foe.global_position);post.designate(foe);post.assign_target();await frames(280)
	solution=post.get_solution(gun)
	check(not solution.is_empty() and not solution.valid,"Target outside Bofors range is explicitly outside the firing envelope")
	check(post.status_text().contains("OUTSIDE FIRING ENVELOPE") and not post.ready_announced,"Observation post also reports impossible gun solutions without a false readiness call")
	foe.global_position=gun.muzzle.global_position+Vector3.UP*200
	aim_post(post,foe.global_position);post.designate(foe);post.assign_target();await frames(280)
	solution=post.get_solution(gun)
	check(not solution.is_empty() and not solution.aimable and not solution.valid,"Prediction respects the gun's maximum elevation rather than promising an impossible shot")
	foe.global_position=saved_position
	aim_post(post,foe.global_position);post.designate(foe);post.assign_target();await frames(300)
	check(post.radio.seen.size()>0 and post.radio.played.is_empty(),"Unrecorded period calls use the existing subtitle queue without fake speech")
	check(post.battery_guns.all(func(g):return g.shots_fired==0 and g.command_station==null),"Observation post never drives or fires the connected guns")
	await key(KEY_F)
	check(mission.pilot.active and mission.interaction.occupied_gun==null and post.assigned_guns.size()==2,"F dismount restores walking while the target assignment persists")
	mission.pilot.global_position=mission.interaction.find_exit(gun,5);await frames(3)
	check(mission.interaction.mount_gun(gun),"Assigned Bofors remains mountable individually")
	var saved_mode:=AAMouseControls.fire_control_mode
	AAMouseControls.set_fire_control_mode(1)
	var yaw: float=gun.mouse_controls.target_yaw
	var pitch: float=gun.mouse_controls.target_elevation
	await frames(15)
	check(not gun.aim_assist.solution.is_empty() and gun.aim_assist.target==foe,"Assisted sight consumes the command post assignment at the mounted gun")
	check(gun.mouse_controls.target_yaw==yaw and gun.mouse_controls.target_elevation==pitch and gun.shots_fired==0,"Assisted mode does not nudge aim or initiate fire")
	AAMouseControls.set_fire_control_mode(0);await frames(3)
	check(gun.aim_assist.solution.is_empty(),"Manual mode retains ordinary reticle without prediction")
	AAMouseControls.set_fire_control_mode(2);await frames(3)
	check(not gun.aim_assist.solution.is_empty() and mission.bofors_mode_option.selected==2,"Training preference exposes lead guidance and synchronizes settings")
	# Real zero-dispersion shot: the solver still has to launch a physical shell.
	for i in 3:
		post.update_solutions(.12);solution=post.get_solution(gun)
		if solution.is_empty():break
		gun.yaw.rotation.y=solution.yaw;gun.elevation.rotation.x=solution.pitch
		gun.mouse_controls.reset_target()
	gun.aim_error_degrees=0
	var before_hp: float=foe.health.hp
	check(gun.fire_round(),"Player's explicit fire command launches an assisted physical round")
	await frames(150)
	check(foe.health.hp<before_hp,"The shell's actual swept collision damages the stationary target")
	# Occlusion must invalidate observations, not disclose a perfect hidden track.
	var block:=StaticBody3D.new();var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(80,80,80);collider.shape=box;block.add_child(collider);game.add_child(block)
	block.global_position=(post.global_position+Vector3.UP*2).lerp(foe.global_position,.5)
	await frames(180)
	check(post.target==null and post.assigned_guns.is_empty() and gun.aim_assist.solution.is_empty(),"Obstructed aircraft becomes target lost and removes assisted solutions")
	block.queue_free();await frames(5)
	check(post.target==null,"Removing occlusion does not automatically reacquire unseen aircraft")
	hidden.team_id=CombatTeams.PLAYER
	hidden.global_position=(post.global_position+Vector3.UP*2).lerp(foe.global_position,.5);await frames(3)
	check(not post.can_observe(foe),"Friendly aircraft also obscure observations of an enemy behind them")
	mission.interaction.leave_gun()
	mission.pilot.global_position=post.to_global(Vector3(0,1.05,3.5));await frames(3)
	check(mission.interaction.mount_gun(post),"Predictor can be re-entered without resetting the world")
	var hostile_pool:=ProjectilePool.new();game.add_child(hostile_pool)
	var post_hp: float=post.hp
	hostile_pool.spawn(post.to_global(Vector3(0,1.5,-5)),post.global_basis.z*850,.2,12,foe.get_rid(),false,CombatTeams.ENEMY)
	await frames(5)
	check(post.hp<post_hp and not post.is_destroyed,"Real swept enemy bullets hit the predictor equipment damage collider")
	post.take_damage(1000);await frames(5)
	check(post.is_destroyed and mission.pilot.active and mission.interaction.occupied_gun==null,"Destroyed occupied post safely ejects its operator")
	check(not gun.is_destroyed and gun.hp>0,"Post loss does not destroy its Bofors")
	mission.pilot.global_position=mission.interaction.find_exit(gun,5);await frames(3)
	check(mission.interaction.mount_gun(gun) and gun.aim_assist.solution.is_empty(),"Gun remains usable manually after predictor loss")
	mission.interaction.leave_gun();foe.queue_free();hidden.take_damage(1000);hidden.queue_free()
	game.restart_malta();await frames(20)
	check(game.field.aa_battery.bofors_posts.size()==4 and game.field.aa_battery.bofors_posts.all(func(p):return p.hp==p.max_hp and p.assigned_guns.is_empty()),"Retry restores exactly four healthy unassigned posts")
	# Four previously staffed posts maintaining separate observed aircraft.
	# Timing is evidence, not a device-independent frame-rate assertion.
	var benchmark_foes: Array[EnemyAircraft]=[]
	for site in game.field.aa_battery.bofors_posts:
		var unit:=EnemyAircraft.new();game.add_child(unit);await frames(2)
		unit.freeze=true;unit.reset_pending=false;unit.ai.set_physics_process(false);unit.set_physics_process(false)
		unit.global_position=site.global_position-site.global_basis.z*600+Vector3.UP*400
		site.measurement_error_metres=0;site.start_operation();aim_post(site,unit.global_position);site.designate(unit);site.assign_target();site.stop_operation()
		benchmark_foes.append(unit)
	var started: int=Time.get_ticks_usec()
	for i in 50:
		for site in game.field.aa_battery.bofors_posts:
			site.clock+=.12;site.update_solutions(.12)
	var elapsed: int=Time.get_ticks_usec()-started
	print("BOFORS PERF: 450 per-gun solutions / 200 post refreshes in ",elapsed," us; mean ",elapsed/200.0," us/post refresh")
	check(game.field.aa_battery.bofors_posts.all(func(p):return p.solutions.size()==p.battery_guns.size() and p.solutions.values().all(func(s):return s.valid) and p.battery_guns.all(func(g):return g.shots_fired==0)),"Four known targets and all nine Bofors solutions update without autonomous fire")
	for unit in benchmark_foes:unit.queue_free()
	game.show_selection(false);game.start_aa_defence();await frames(20)
	var director: DiveDefenceMission=game.aa_defence
	director.set_physics_process(false)
	var local_post: BoforsCommandPost=game.field.aa_battery.bofors_posts.filter(func(p):return p.field_id==game.home_airfield)[0]
	check(director.choose_target(2)==local_post,"Stuka attack behaviour can select the local Bofors predictor")
	var defended: BritishAAGun=local_post.battery_guns[0]
	game.malta_mission.pilot.global_position=game.malta_mission.interaction.find_exit(defended,5);await frames(3)
	check(game.malta_mission.interaction.mount_gun(defended) and director.choose_target(0)==defended and director.choose_target(2)==local_post,"The real three-aircraft wave can attack the predictor while other Stukas threaten the manned gun")
	game.malta_mission.interaction.leave_gun()
	local_post.take_damage(1000);await frames(3)
	check(not director.is_finished() and director.operational_guns()==6,"Losing only the predictor preserves AA mission and existing gun-survival rule")
	game.restart_malta();await frames(20)
	director=game.aa_defence;director.set_physics_process(false)
	mission=game.malta_mission
	local_post=game.field.aa_battery.bofors_posts.filter(func(p):return p.field_id==game.home_airfield)[0]
	mission.pilot.global_position=local_post.to_global(Vector3(0,1.05,3.5));await frames(3)
	check(mission.interaction.mount_gun(local_post),"AA mission operator can staff the Bofors predictor")
	await frames(3)
	var bomb:=MissionBomb.new();bomb.damage_pilots=true;bomb.impact_effects=game;game.add_child(bomb)
	bomb.explode(mission.pilot.global_position);await frames(5)
	check(local_post.is_destroyed and mission.pilot.health.hp==0,"Actual bomb blast can destroy the predictor and kill its player operator")
	check(director.phase=="FAILED" and director.result_count==1,"Operator death retains the mission's immediate one-shot failure rule")
	AAMouseControls.set_fire_control_mode(saved_mode)
	game.queue_free();await frames(8)
	print("BOFORS PREDICTOR RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)
