extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok:passed+=1;print("PASS: ",label)
	else:failed+=1;push_error("FAIL: "+label)
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	var world:=Node3D.new();root.add_child(world)
	var planes: Array[FlightAircraft]=[]
	var results: Dictionary={}
	for i in AlliedAircraft.KINDS.size():
		var kind: String=AlliedAircraft.KINDS[i]
		var plane: FlightAircraft=AlliedAircraft.create(kind);plane.reset_position=Vector3(i*500,800,0);world.add_child(plane)
		plane.request_reset();plane.pending_reset_pose=Transform3D(Basis(Vector3.RIGHT,.03),Vector3(i*500,800,0));plane.pending_reset_velocity=Vector3(0,0,-55)
		plane.pilot.automated=true;planes.append(plane);results[kind]={}
	for i in 6:await physics_frame
	for plane in planes:plane.pilot.throttle=1;plane.gear.extended=not plane.gear.retractable
	for tick in 5400:
		for i in planes.size():
			var plane: FlightAircraft=planes[i]
			var desired: float=clampf(.02+(800-plane.global_position.y)*.006,-.15,.18)
			plane.pilot.pitch=clampf((desired-plane.rotation.x)*4,-.6,.6)
			if tick==599:results[AlliedAircraft.KINDS[i]].speed_after_5s=plane.airspeed
		await physics_frame
	for i in planes.size():results[AlliedAircraft.KINDS[i]].speed_45s=planes[i].airspeed;results[AlliedAircraft.KINDS[i]].height=planes[i].global_position.y
	for tick in 2400:
		for plane in planes:plane.pilot.pitch=clampf((.10-plane.rotation.x)*4,-.6,.6)
		await physics_frame
	for i in planes.size():results[AlliedAircraft.KINDS[i]].climb_mps=(planes[i].global_position.y-results[AlliedAircraft.KINDS[i]].height)/20
	var h: Dictionary=results.hurricane;var s: Dictionary=results.spitfire;var g: Dictionary=results.sea_gladiator
	check(h.speed_45s>g.speed_45s and h.speed_45s<s.speed_45s,"Measured full-power speed falls between Sea Gladiator and Spitfire")
	check(h.speed_after_5s>g.speed_after_5s and h.speed_after_5s<s.speed_after_5s,"Measured acceleration is distinct and between the existing fighters")
	check(h.climb_mps>g.climb_mps and h.climb_mps<s.climb_mps,"Measured climb falls between existing fighters under the same control law")
	for i in planes.size():
		var plane: FlightAircraft=planes[i]
		plane.request_reset();plane.pending_reset_pose=Transform3D(Basis(Vector3.RIGHT,.03),Vector3(i*500,800,0));plane.pending_reset_velocity=Vector3(0,0,-80)
	for i in 6:await physics_frame
	for plane in planes:plane.engine_running=false;plane.pilot.throttle=0;plane.gear.extended=not plane.gear.retractable
	for tick in 600:
		for plane in planes:
			var desired: float=clampf(.02+(800-plane.global_position.y)*.006,-.15,.18)
			plane.pilot.pitch=clampf((desired-plane.rotation.x)*4,-.6,.6)
		await physics_frame
	for i in planes.size():results[AlliedAircraft.KINDS[i]].coast_speed_5s=planes[i].airspeed
	check(results.hurricane.coast_speed_5s>results.sea_gladiator.coast_speed_5s and results.hurricane.coast_speed_5s<results.spitfire.coast_speed_5s,"Measured power-off energy retention differs and falls between existing fighters")
	print("HURRICANE PERFORMANCE ",JSON.stringify(results))
	world.queue_free();for i in 5:await physics_frame
	print("HURRICANE PERFORMANCE RESULT: %d/%d passed"%[passed,passed+failed]);quit(1 if failed else 0)
