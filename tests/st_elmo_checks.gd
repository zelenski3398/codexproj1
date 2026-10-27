extends SceneTree
var passed:int=0
var failed:int=0
var game: Node3D
func _initialize() -> void:call_deferred("run")
func frames(n:int) -> void:
	for i in range(n):await physics_frame
func check(ok:bool,label:String) -> void:
	if ok:passed+=1;print("PASS: ",label)
	else:failed+=1;push_error("FAIL: "+label)
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	game.start_malta("st_elmo","spitfire","encounter")
	await frames(20)
	var mission: MaltaMission=game.malta_mission
	var world: MaltaWorld=mission.world
	var fort: StElmoBattery=world.fort_battery
	check(fort.guns.size()==3 and world.aa_battery.guns.size()==18 and get_nodes_in_group("friendly_aa").size()==21,"Exactly three additional Bofors coexist with all eighteen airfield guns")
	check(game.departure_spawn=="st_elmo" and mission.pilot.global_position.distance_to(StElmoLocations.position_for("st_elmo"))<2,"Departure spawns on foot inside St Elmo without remote mounting")
	check(fort.guns.all(func(g):return not g.weapon.heavy and g.rounds_per_second==2 and g.crew.seated),"Three existing Bofors weapons start with seated British crews and 2 rounds/sec")
	check(fort.guns.all(func(g):return not g.mounted and g.shots_fired==0),"Unoccupied fort guns remain idle, with no autonomous fire")
	var forward:=Vector3(world.valletta_city.layout.grid_forward_xz[0],0,world.valletta_city.layout.grid_forward_xz[1])
	var right:=Vector3(-forward.z,0,forward.x)
	var layout:=StElmoLocations.data()
	var center:=Vector3(layout.center_world[0],layout.deck,layout.center_world[1])
	var route:Dictionary=layout.courtyard_ramp
	mission.pilot.global_position=fort_point(route.start)+Vector3.UP*1.05
	mission.pilot.velocity=Vector3.ZERO
	mission.pilot.yaw=atan2(-forward.x,-forward.z)
	Input.action_press("throttle_up")
	await frames(430)
	Input.action_release("throttle_up")
	await frames(3)
	check(mission.pilot.global_position.y>float(route.end[2])+.8 and mission.pilot.global_position.distance_to(fort_point(route.end)+Vector3.UP*1.05)<3,"Existing soldier physics walks up the revised courtyard ramp onto the raised floor")
	# The treads use a baked smooth collider, preserving the soldier controller.
	var stairs:Dictionary=layout.courtyard_steps
	mission.pilot.global_position=fort_point(stairs.start)+Vector3.UP*1.05
	mission.pilot.velocity=Vector3.ZERO
	mission.pilot.yaw=atan2(-forward.x,-forward.z)
	Input.action_press("throttle_up")
	await frames(200)
	Input.action_release("throttle_up")
	await frames(3)
	check(mission.pilot.global_position.distance_to(fort_point(stairs.end)+Vector3.UP*1.05)<2 and mission.pilot.global_position.y>float(stairs.end[2])+.8,"Soldier can climb the eight courtyard treads via their baked ramp collision without jumping")
	# Actual controller walks the complete road/gate/upper-court route. Only
	# the initial scenario pose is assigned; every leg uses normal movement.
	var approach:Array=layout.approach_route
	mission.pilot.global_position=fort_point(approach[0])+Vector3.UP*1.05
	mission.pilot.velocity=Vector3.ZERO
	await frames(4)
	var reached:bool=true
	Input.action_press("throttle_up")
	for i in range(1,approach.size()):
		var target:Vector3=fort_point(approach[i])
		var budget:int=ceili(Vector2(target.x-mission.pilot.global_position.x,target.z-mission.pilot.global_position.z).length()/mission.pilot.walking_speed*120*1.5)+180
		var arrived:bool=false
		for tick in range(budget):
			var delta:Vector3=target-mission.pilot.global_position
			if Vector2(delta.x,delta.z).length()<.65:
				arrived=true;break
			mission.pilot.yaw=atan2(-delta.x,-delta.z)
			await physics_frame
		if not arrived:
			print("BLOCKED ROUTE LEG ",i," position=",mission.pilot.global_position," target=",target)
			reached=false;break
	Input.action_release("throttle_up")
	check(reached and mission.pilot.global_position.y>float(layout.inner_deck)+1.9,"Soldier can walk from the existing road through both gates to the upper courtyard")
	check(layout.version==2 and layout.outline_grid.size()>14 and layout.inner_outline_grid.size()>12,"Fort uses separate irregular outer and inner photographic massing")
	check(fort.reference_camera!=null and not fort.reference_camera.current and fort.reference_camera.global_position.z<center.z and (-fort.reference_camera.global_basis.z).dot(-forward)>.25,"Optional reference camera sits north and looks toward Valletta without stealing player view")
	var supported:bool=true
	for item in fort.guns:
		var ray:=PhysicsRayQueryParameters3D.create(item.global_position+Vector3.UP,item.global_position+Vector3.DOWN*2,1)
		var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
		supported=supported and not hit.is_empty() and absf(hit.position.y-item.global_position.y)<.1 and world.valletta_city.is_ancestor_of(hit.collider)
	check(supported,"All three relocated gun pads have matching structural collision at their feet")
	for i in range(layout.gun_approaches.size()):
		var access:Dictionary=layout.gun_approaches[i]
		mission.pilot.global_position=fort_point(access.start)+Vector3.UP*1.05
		mission.pilot.velocity=Vector3.ZERO
		var direction:Vector3=fort_point(access.end)-fort_point(access.start)
		mission.pilot.yaw=atan2(-direction.x,-direction.z)
		Input.action_press("throttle_up")
		await frames(595)
		Input.action_release("throttle_up")
		await frames(3)
		var expected:Vector3=fort_point(access.end)+Vector3.UP*1.05
		print("GUN WALK ",i+1," position=",mission.pilot.global_position," expected=",expected)
		check(mission.pilot.global_position.distance_to(expected)<2,"Normal soldier controls reach gun platform %d up its access ramp"%(i+1))
	var identity: int=world.get_instance_id()
	var aircraft: FlightAircraft=mission.initial_aircraft
	aircraft.take_damage(10)
	var hp:float=aircraft.health.hp
	var gun: StElmoBofors=fort.guns[0]
	for id in ["st_elmo_1","st_elmo_2","st_elmo_3","luqa","ta_qali","hal_far","st_elmo"]:
		check(mission.teleport_to(id),"Safe live-world travel to "+id)
		await frames(3)
	check(world.get_instance_id()==identity and aircraft.health.hp==hp and mission.fleet.size()==9 and game.encounters.active.is_empty(),"Travel preserves the world, fleet damage, aircraft state and peaceful encounter")
	mission.teleport_to("st_elmo_2")
	await frames(3)
	check(mission.interaction.mount_gun(fort.guns[1]),"Second gun supports crew replacement")
	await frames(90)
	check(mission.interaction.leave_gun(),"Second gun supports safe dismount")
	await frames(90)
	mission.teleport_to("st_elmo_1")
	await frames(3)
	check(mission.interaction.mount_gun(gun),"Player can replace the crew at the first gun")
	await frames(90)
	check(gun.mounted and gun.crew.waiting and not gun.crew.seated and mission.interaction.occupied_gun==gun and not mission.pilot.active,"One gun controller owns input while its crew waits off the seat")
	check(not mission.teleport_to("luqa"),"Travel refuses to leave a mounted gun/controller behind")
	check(not fort.command_active(),"Individual mode is the default")
	Input.action_press("fire")
	await frames(130)
	Input.action_release("fire")
	await frames(2)
	check(gun.shots_fired>0 and fort.guns[1].shots_fired==0 and fort.guns[2].shots_fired==0,"Individual trigger fires only the occupied Bofors")
	fort.toggle(gun)
	check(fort.command_active() and fort.guns[1].command_station==fort,"B toggle connects only the two other fort guns")
	gun.yaw.rotation.y=PI
	gun.elevation.rotation.x=deg_to_rad(60)
	gun.mouse_controls.reset_target()
	Input.action_press("fire")
	await frames(300)
	Input.action_release("fire")
	await frames(3)
	print("FORT SHOTS ",fort.guns.map(func(g):return g.shots_fired)," aim ",fort.aim_point)
	check(fort.guns.all(func(g):return g.shots_fired>0),"Holding player fire sends aligned physical shots from all three muzzles")
	check(world.aa_battery.guns.all(func(g):return g.shots_fired==0),"Fort command never activates existing airfield guns")
	# Real physical obstruction test through the same remote firing path.
	fort.set_physics_process(false)
	var remote: BritishAAGun=fort.guns[1]
	remote.set_physics_process(false)
	var start: Vector3=remote.muzzle.global_position
	var direction: Vector3=-remote.muzzle.global_basis.z
	var blocker:=StaticBody3D.new()
	var box:=CollisionShape3D.new()
	var mesh:=BoxShape3D.new()
	mesh.size=Vector3(10,10,5);box.shape=mesh
	blocker.add_child(box);world.add_child(blocker)
	blocker.global_transform=Transform3D(remote.muzzle.global_basis,start+direction*20)
	await frames(2)
	fort.aim_point=start+direction*150
	fort.orders[remote]=true
	remote.cooldown=0
	var before_blocked:int=remote.shots_fired
	fort.drive_gun(remote,.5)
	check(remote.shots_fired==before_blocked,"A physical obstruction prevents commanded remote fire")
	blocker.queue_free()
	await frames(2)
	fort.drive_gun(remote,.5)
	check(remote.shots_fired>before_blocked,"Removing obstruction permits a real shell from the remote muzzle")
	remote.set_physics_process(true)
	fort.set_physics_process(true)
	fort.guns[1].take_damage(1000)
	check(fort.command_active() and fort.operational_count()==2,"Losing a remote gun preserves command of surviving guns")
	var counts: Array=fort.guns.map(func(g):return g.shots_fired)
	await frames(90)
	check(fort.guns.map(func(g):return g.shots_fired)==counts,"Trigger release stops battery fire")
	paused=true
	await process_frame
	check(not fort.command_active(),"Pause blocks all battery commands immediately")
	paused=false
	fort.cancel()
	gun.take_damage(20)
	check(mission.interaction.leave_gun(),"Dismount restores soldier movement at a collision-checked exit")
	await frames(90)
	check(gun.crew.seated and not gun.mounted and not fort.command_active() and gun.hp==130,"Crew returns to the seat; damage persists; battery stays idle")
	mission.teleport_to("st_elmo_3")
	await frames(3)
	check(mission.interaction.mount_gun(fort.guns[2]),"Third gun supports the same crew-replacement interaction")
	await frames(90)
	check(mission.interaction.leave_gun(),"Third gun has a safe dismount")
	await frames(90)
	mission.pilot.global_position=StElmoLocations.position_for("st_elmo_1")
	await frames(2)
	check(mission.interaction.mount_gun(gun),"Damaged gun can be re-entered")
	gun.take_damage(1000)
	await frames(4)
	check(gun.is_destroyed and not gun.crew.seated and mission.interaction.occupied_gun==null and mission.pilot.active,"Destroyed occupied gun releases player and disables its crew")
	game.restart_malta()
	await frames(12)
	check(game.malta_mission.world!=world and game.departure_spawn=="st_elmo" and game.malta_mission.world.fort_battery.guns.size()==3 and get_nodes_in_group("friendly_aa").size()==21,"Retry restores the selected fort spawn and one clean three-gun battery")
	game.queue_free()
	await frames(6)
	print("ST ELMO RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)

func fort_point(value:Array) -> Vector3:
	return Vector3(value[0],value[2],value[1])
