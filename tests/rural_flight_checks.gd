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
	GameAudioMixer.instance.playback_enabled=false
	var game=load("res://main.tscn").instantiate();root.add_child(game);game.start_free_roam("spitfire");await frames(80)
	check(game.malta_mission.board_nearest(),"Original manual boarding works with rural vegetation present")
	var trees: MalteseTrees=game.field.landscape_details.trees
	var group: Array=trees.layout.trees.filter(func(t):return t.context=="olive_grove" and t.position[2]>0)
	var point:=MaltaGeography.vector(group[group.size()/2].position)
	var plane: FlightAircraft=game.aircraft
	# Disclosed low-flight initial pose; all subsequent movement uses forces.
	plane.request_reset();plane.pending_reset_pose=Transform3D(Basis(Vector3.RIGHT,.03),point+Vector3.UP*110);plane.pending_reset_velocity=Vector3(0,0,-65)
	plane.engine_running=true;plane.pilot.automated=true;await frames(3)
	var origin: Vector3=plane.global_position;var identity: int=game.field.get_instance_id();var minimum_agl: float=INF
	for tick in 1200:
		var probe: Vector3=plane.global_position-plane.global_basis.z*180
		var hit:=plane.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(probe+Vector3.UP*1000,probe-Vector3.UP*1500,1))
		var target: float=(float(hit.position.y) if not hit.is_empty() else point.y)+110
		var desired: float=clampf((target-plane.global_position.y)*.006,-.08,.2)
		plane.pilot.pitch=clampf((desired-plane.rotation.x)*3-plane.angular_velocity.x*.4,-.5,.5)
		plane.pilot.roll=clampf(-plane.global_basis.x.y*3-plane.angular_velocity.z*.4,-.5,.5)
		plane.pilot.throttle=.75
		await physics_frame
		minimum_agl=minf(minimum_agl,plane.altitude)
		if plane.is_crashed:break
	check(not plane.is_crashed and not plane.is_destroyed and plane.health.hp==100 and minimum_agl>20,"Real low flight over fields and tree groups retains healthy aircraft and terrain clearance")
	check(plane.global_position.distance_to(origin)>450 and game.field.get_instance_id()==identity,"Continuous aerodynamic flight traverses rural scenery without world reload")
	check(trees.collider_count<=trees.maximum_colliders and trees.instance_count==4800,"Flight keeps trunk physics bounded and planting stable")
	check(game.encounters.active.is_empty() and game.malta_mission.fleet.size()>=6,"Scenery changes preserve peaceful departure and original stationed aircraft")
	print("LOW FLIGHT minAGL=",minimum_agl," distance=",plane.global_position.distance_to(origin)," colliders=",trees.collider_count)
	game.queue_free();await frames(5);print("RURAL FLIGHT RESULT: %d/%d passed"%[passed,passed+failed]);quit(1 if failed else 0)
