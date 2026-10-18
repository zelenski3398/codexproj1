extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print("PASS: " if ok else "FAIL: ",label)
func ray(hangar: AircraftHangar, a: Vector3, b: Vector3, exclude: Array[RID] = []) -> Dictionary:
	return hangar.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(hangar.to_global(a),hangar.to_global(b),1,exclude))
func inspect(hangar: AircraftHangar) -> void:
	check(hangar.truss_count==7 and hangar.find_children("*","MeshInstance3D",true,false).size()==8,hangar.display_name+": seven repeated trusses; geometry merged into eight material batches")
	var arrays := hangar.visual.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var rendered_ridges := 0
	for index in indices:
		if vertices[index].y > 15.9: rendered_ridges += 1
	check(rendered_ridges >= 12,"Front/rear gable ridge vertices are indexed and actually render")
	var bounds := hangar.visual.get_aabb()
	check(absf(bounds.size.x-48.35)<.01 and absf(bounds.size.z-36.35)<.01,"Visible walls match physical footprint dimensions")
	var clear := true
	for x in [-20.0,-10.0,0.0,10.0,20.0]:
		for height in [1.0,4.0,8.0]:
			if not ray(hangar,Vector3(x,height,-25),Vector3(x,height,14)).is_empty(): clear=false
	check(clear,hangar.display_name+": entire 40 m sampled entrance and interior are clear, without centre posts")
	var walls := true
	for side in [-1.0,1.0]:
		var hit := ray(hangar,Vector3(0,4,0),Vector3(side*28,4,0))
		walls = walls and not hit.is_empty() and hit.collider==hangar
	var rear := ray(hangar,Vector3(0,4,0),Vector3(0,4,23))
	var roof := ray(hangar,Vector3(10,20,0),Vector3(10,8,0))
	check(walls and not rear.is_empty() and rear.collider==hangar and not roof.is_empty() and roof.collider==hangar,hangar.display_name+": side/rear/roof collision matches the open shell")
	var max_gap := 0.0
	for x in [-20.0,0.0,20.0]:
		for z in [-19.0,0.0,17.0]:
			var hit := ray(hangar,Vector3(x,2,z),Vector3(x,-2,z),[hangar.get_rid()])
			if hit.is_empty(): max_gap=INF
			else: max_gap=maxf(max_gap,absf(hangar.to_local(hit.position).y-hangar.floor_height(x,z)))
	check(max_gap<.12,hangar.display_name+": floor fitted to existing terrain; max gap %.3f m"%max_gap)
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	var country := Airfield.new()
	root.add_child(country)
	await frames(5)
	check(get_nodes_in_group("aircraft_hangars").size()==3,"Original test runway replaces all three solid placeholder hangars")
	for hangar in get_nodes_in_group("aircraft_hangars"): inspect(hangar)
	var home: AircraftHangar = get_nodes_in_group("aircraft_hangars")[0]
	# Real controls/forces taxi two different aircraft through the centre opening.
	for kind in ["spitfire","gladiator"]:
		var aircraft: FlightAircraft = SeaGladiator.new() if kind=="gladiator" else FlightAircraft.new()
		root.add_child(aircraft)
		aircraft.request_reset()
		aircraft.pending_reset_pose=home.global_transform*Transform3D(Basis(Vector3.UP,PI)*Basis(Vector3.RIGHT,.117),Vector3(0,1.18,-31))
		await frames(5)
		aircraft.pilot.automated=true
		aircraft.pilot.throttle=.24
		for tick in 2400:
			await physics_frame
			if home.to_local(aircraft.global_position).z > -4 or aircraft.is_crashed: break
		var pose := home.to_local(aircraft.global_position)
		check(pose.z > -6 and pose.z < 16 and aircraft.health.hp==100 and not aircraft.is_crashed,kind+": real physics taxis through opening into hangar without collision damage; z=%.2f"%pose.z)
		aircraft.queue_free()
		await frames(3)
	country.queue_free()
	await frames(5)
	for repetition in 2:
		var world := MaltaWorld.new()
		root.add_child(world)
		await frames(10)
		check(get_nodes_in_group("aircraft_hangars").size()==6,"Malta construction %d: exactly two replacement hangars at each existing runway"%(repetition+1))
		for field in world.fields.values():
			check(field.installations.size()==2 and field.installations.all(func(h):return h is AircraftHangar),field.record.id+": existing persistent damage targets retained")
			for hangar in field.installations:
				if repetition==0: inspect(hangar)
				var local: Vector3 = field.to_local(hangar.global_position)
				check(absf(local.x-100)<.01 and hangar.global_basis.y.dot(Vector3.UP)>.99999,field.record.id+": upright footprint extends outward from unchanged 82 m frontage")
			var clear_lanes := true
			for x in [37.0,47.0,59.0,64.0,78.0]:
				var a: Vector3=field.to_global(Vector3(x,2,field.runway_length*.31-175))
				var b: Vector3=field.to_global(Vector3(x,2,field.runway_length*.31+115))
				var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
				if not hit.is_empty() and hit.collider is AircraftHangar: clear_lanes=false
			check(clear_lanes,field.record.id+": runways, AA, parking, soldier and driving corridors remain clear of hangars")
		var damaged: AircraftHangar=world.fields.luqa.installations[0]
		damaged.take_damage(30)
		await frames(2)
		check(damaged.hp==220 and not damaged.is_destroyed,"Hangar uses existing persistent installation HP")
		damaged.take_damage(1000)
		var children_before := damaged.get_child_count()
		damaged.take_damage(1000)
		check(damaged.is_destroyed and damaged.hp==0 and damaged.get_child_count()==children_before,"Destruction is one-shot and retains structural ruins/collision")
		world.queue_free()
		await frames(5)
		check(get_nodes_in_group("aircraft_hangars").is_empty(),"Teardown removes all previous hangars before retry")
	print("HANGAR RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)
