extends SceneTree
var passed := 0
var failed := 0
var session: Node3D
var mission: MaltaMission
var controls: AirfieldInteraction
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if value: passed += 1; print("PASS: ",message)
	else: failed += 1; push_error("FAIL: "+message)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func exclusive() -> bool:
	var count: int = int(mission.pilot.active) + int(controls.occupied_gun != null) + int(controls.occupied_vehicle != null) + int(mission.occupied != null)
	return count == 1 and mission.world.aa_battery.guns.filter(func(g):return g.mounted).size() <= 1
func release_controls() -> void:
	for action in ["throttle_up","throttle_down","rudder_left","rudder_right","roll_left","roll_right","pitch_down","pitch_up","brake","fire"]: Input.action_release(action)
func walk_to(point: Vector3) -> void:
	mission.pilot.global_position = point
	mission.pilot.velocity = Vector3.ZERO
	await frames(4)
func run() -> void:
	session = load("res://main.tscn").instantiate()
	root.add_child(session)
	await frames(8)
	session.start_malta("ta_qali","spitfire","interception")
	await frames(20)
	mission = session.malta_mission
	controls = mission.interaction
	var field: MaltaAirfield = mission.world.fields.ta_qali
	var gun: BritishAAGun = mission.world.aa_battery.guns[0]
	var truck: MilitaryTruck = mission.world.trucks[0]
	var world_id := mission.world.get_instance_id()
	var initial_cameras := cameras(root)
	check(mission.world.trucks.size() == 3 and get_nodes_in_group("airfield_trucks").size() == 3,"One truck per airfield, including selected departure")
	check(truck.model.wheel_pivots.size()==4 and truck.model.steering_pivots.size()==2,"Four visible rolling wheels and two steering pivots")
	check(exclusive() and mission.pilot.camera.current,"Initial walking controller/camera exclusively active")
	check(not controls.mount_gun(gun) and not controls.enter_vehicle(truck),"No remote mounting from aircraft parking")
	for target_gun in [mission.world.aa_battery.guns[0],mission.world.aa_battery.guns[1]]:
		await walk_to(target_gun.global_position + field.global_basis.x*5 + Vector3.UP*1.05)
		check(controls.prompt()=="E Mount AA Gun", "Nearby manual mount prompt")
		check(controls.interact() and controls.occupied_gun==target_gun and exclusive(),"Both guns mount through exclusive E interaction")
		var yaw: float = target_gun.yaw.rotation.y
		Input.action_press("roll_right")
		Input.action_press("pitch_down")
		Input.action_press("fire")
		await frames(120)
		release_controls()
		check(target_gun.shots_fired>0 and target_gun.yaw.rotation.y != yaw,"Mounted aim/fire works")
		check(target_gun.camera.current and controls.sight.visible and "Exit AA Gun" in controls.prompt(),"Gunner camera, reticle and exit instructions")
		target_gun.take_damage(20)
		var hp: float = target_gun.hp
		check(controls.interact() and mission.pilot.active and mission.pilot.camera.current and exclusive(),"Exit restores on-foot input and camera")
		var shots: int = target_gun.shots_fired
		Input.action_press("fire")
		Input.action_press("roll_right")
		await frames(90)
		release_controls()
		check(target_gun.shots_fired==shots and not target_gun.mounted,"Exited gun stays idle while keys are held")
		check(controls.mount_gun(target_gun) and target_gun.hp==hp,"Re-enter retains gun damage")
		check(controls.leave_gun(),"Repeated mount/exit remains safe")
	await walk_to(truck.global_position + field.global_basis.x*2.8 + Vector3.UP*1.05)
	check(controls.prompt()=="E Enter Military Truck" and controls.interact(),"Enter nearby truck using established E input")
	check(exclusive() and truck.camera.current and truck.model.driver.visible,"Truck owns camera/input and seated driver")
	check(not controls.mount_gun(gun) and not mission.board_aircraft(mission.initial_aircraft),"Cannot mount guns/planes while driving")
	var start := truck.global_position
	Input.action_press("throttle_up")
	await frames(100)
	check(truck.global_position.distance_to(start)>1 and truck.speed>1,"W accelerates and drives with collision/gravity")
	check(not controls.leave_vehicle(),"Exit rejected while moving")
	Input.action_press("brake")
	await frames(80)
	release_controls()
	check(absf(truck.speed)<0.1 and truck.grounded,"Space brakes to stable ground stop")
	Input.action_press("throttle_down")
	await frames(100)
	check(truck.speed < -1,"S reverses")
	Input.action_release("throttle_down")
	Input.action_press("brake")
	await frames(80)
	release_controls()
	# Clear apron route between both gun positions. Waypoints use the existing
	# action inputs and physics; no body transform changes during navigation.
	var near_first := field.to_global(Vector3(44,0,field.runway_length*.31+90))
	var route: Array[Vector3] = [field.to_global(Vector3(78,0,field.runway_length*.31+78)),near_first]
	check(await drive_route(truck,route),"Physically drive to first AA position along clear apron")
	check(controls.leave_vehicle() and exclusive() and mission.pilot.camera.current,"Park/exit safely at first gun")
	check(mission.pilot.global_position.distance_to(mission.world.aa_battery.guns[1].global_position)<12,"Vehicle exit leaves a short clear walk to the gun")
	# Return to the same truck, then drive the continuous lane to the other gun.
	await walk_to(truck.global_position + truck.global_basis.x*2.8 + Vector3.UP*1.05)
	check(controls.enter_vehicle(truck),"Re-enter the same parked truck")
	var route_second: Array[Vector3] = [field.to_global(Vector3(76,0,field.runway_length*.31+75)),field.to_global(Vector3(76,0,field.runway_length*.31-75)),field.to_global(Vector3(44,0,field.runway_length*.31-90))]
	check(await drive_route(truck,route_second),"Physically drive to second AA position without scene reload")
	check(controls.leave_vehicle() and exclusive(),"Park/exit at second gun")
	var parked := truck.global_position
	Input.action_press("throttle_up")
	await frames(60)
	release_controls()
	check(absf(truck.speed)<.1 and truck.global_position.distance_to(parked)<.1,"Unoccupied truck holds parking brake and ignores throttle")
	# Isolated solid-contact fixtures: all movement after each initial pose is
	# normal W input and CharacterBody collision, not transform-based driving.
	var collision_checks: Array[Dictionary] = [
		{"name":"hangar","position":Vector3(78,0.04,field.runway_length*.31-45),"yaw":-PI/2,"minimum":78.0},
		{"name":"parked aircraft","position":Vector3(70,0.04,field.runway_length*.31-35),"yaw":PI/2,"minimum":61.5},
		{"name":"AA emplacement","position":Vector3(45,0.04,field.runway_length*.31-90),"yaw":PI/2,"minimum":39.8}
	]
	for spec in collision_checks:
		truck.global_position = field.to_global(spec.position)
		truck.rotation.y = -deg_to_rad(float(field.record.heading)) + spec.yaw
		truck.speed = 0
		truck.velocity = Vector3.ZERO
		await frames(4)
		await walk_to(truck.global_position + truck.global_basis.x*2.8 + Vector3.UP*1.05)
		check(controls.enter_vehicle(truck),"Enter truck for "+spec.name+" collision fixture")
		Input.action_press("throttle_up")
		await frames(240)
		release_controls()
		Input.action_press("brake")
		await frames(80)
		release_controls()
		var local: Vector3 = field.to_local(truck.global_position)
		check(local.x >= spec.minimum and local.x < (82 if spec.name=="hangar" else 70),"Solid "+spec.name+" blocks driving through it")
		check(absf(truck.rotation.x)<.001 and absf(truck.rotation.z)<.001 and truck.grounded,"Chassis remains upright on uneven graded apron")
		check(controls.leave_vehicle(),"Safe low-speed exit after solid contact")
	check(mission.world.get_instance_id()==world_id and session.interception.phase=="CHECKPOINT" and session.interception.elapsed==0,"Travel retains world and stopped checkpoint mission state")
	await walk_to(gun.global_position - field.global_basis.x*4 + Vector3.UP*1.05)
	check(controls.mount_gun(gun),"Mount damaged gun again before destruction")
	gun.take_damage(1000)
	await frames(4)
	check(controls.occupied_gun==null and mission.pilot.active and exclusive() and mission.pilot.camera.current,"Occupied destruction safely restores foot control beside wreck")
	check(mission.pilot.global_position.distance_to(gun.global_position)<12,"Destroyed gun ejects locally, not to mission start")
	check(cameras(root).size()==initial_cameras.size(),"Repeated ground transitions create no duplicate cameras")
	check(cameras(root).filter(func(c):return c.current).size()==1,"Exactly one world camera remains current")
	var second: BritishAAGun = mission.world.aa_battery.guns[1]
	await walk_to(second.global_position + field.global_basis.x*5 + Vector3.UP*1.05)
	check(controls.mount_gun(second),"Second gun remains independently usable")
	session.encounters.ended = true
	Input.action_press("fire")
	var before: int = second.shots_fired
	await frames(5)
	release_controls()
	check(second.shots_fired==before and controls.occupied_gun==null,"Mission end prevents firing and exits occupied gun")
	session.encounters.ended = false
	second.take_damage(1000)
	await walk_to(mission.initial_aircraft.global_position + field.global_basis.x*5 + Vector3.UP)
	check(mission.board_nearest(),"Both guns lost still leaves aircraft fallback available")
	check(exclusive() and mission.initial_aircraft.input_enabled,"Aircraft becomes sole active controller")
	var old_truck_id := truck.get_instance_id()
	session.restart_malta()
	await frames(20)
	mission = session.malta_mission
	controls = mission.interaction
	check(mission.world.trucks.size()==3 and get_nodes_in_group("airfield_trucks").size()==3 and mission.world.trucks[0].get_instance_id()!=old_truck_id,"Retry replaces trucks once, without duplicates")
	check(mission.world.aa_battery.guns.all(func(g):return g.hp==g.max_hp and not g.mounted) and exclusive(),"Retry restores gun health, parking and walking controller")
	# A real running Survival wave, rather than an invented defence/base-health mode.
	session.show_selection()
	session.start_malta("ta_qali","spitfire","survival")
	await frames(20)
	mission = session.malta_mission
	controls = mission.interaction
	truck = mission.world.trucks[0]
	var battle_world := mission.world.get_instance_id()
	var enemy_id: int = session.encounters.active[0].get_instance_id()
	var enemy_position: Vector3 = session.encounters.active[0].global_position
	await walk_to(truck.global_position+truck.global_basis.x*2.8+Vector3.UP*1.05)
	check(controls.enter_vehicle(truck),"Enter truck during actual Survival battle")
	Input.action_press("throttle_up")
	await frames(240)
	release_controls()
	check(mission.world.get_instance_id()==battle_world and session.encounters.stage==1 and session.encounters.active[0].get_instance_id()==enemy_id,"Driving preserves live world, wave and enemy identity")
	check(session.encounters.active[0].global_position.distance_to(enemy_position)>20,"Enemy physics/AI continues during ground travel")
	print("AIRFIELD CONTROLS RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)

func drive_route(truck: MilitaryTruck,route: Array[Vector3]) -> bool:
	for waypoint in route:
		var arrived := false
		for frame in range(6000):
			var offset: Vector3 = waypoint-truck.global_position
			offset.y=0
			if offset.length()<2.7:
				arrived=true
				break
			var desired := atan2(-offset.x,-offset.z)
			var error := wrapf(desired-truck.rotation.y,-PI,PI)
			var steer := clampf(-error*2,-1,1)
			Input.action_release("rudder_left")
			Input.action_release("rudder_right")
			Input.action_press("rudder_right" if steer>0 else "rudder_left",absf(steer))
			Input.action_press("throttle_up",0.42)
			await physics_frame
		if not arrived:
			print("DRIVE MISSED waypoint=",waypoint," actual=",truck.global_position," speed=",truck.speed)
			release_controls()
			return false
	release_controls()
	Input.action_press("brake")
	await frames(80)
	release_controls()
	return true

func cameras(node: Node) -> Array[Camera3D]:
	var result: Array[Camera3D] = []
	if node is Camera3D: result.append(node)
	for child in node.get_children(): result.append_array(cameras(child))
	return result
