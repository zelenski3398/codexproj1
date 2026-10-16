extends SceneTree
var passed: int = 0
var failed: int = 0
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in range(n):await physics_frame
func check(ok: bool, label: String) -> void:
	if ok:passed+=1;print("PASS: ",label)
	else:failed+=1;push_error("FAIL: "+label)
func run() -> void:
	var world:=MaltaWorld.new()
	root.add_child(world)
	await frames(5)
	var city: MdinaCity=world.mdina_city
	var data: Dictionary=city.layout
	check(city.ready_for_flight and city.scale==Vector3.ONE,"Mdina is part of the existing continuous Malta world at metre scale")
	check(absf(city.position.x-277.514968)<.02 and absf(city.position.z-4782.307970)<.02,"35.8869 N / 14.4034 E projects to the correct existing world coordinates")
	check(absf(float(data.reference_terrain_height)-196.110954)<.05,"Reference elevation is sampled from the existing hill, not a guessed Y coordinate")
	check(data.reference_lon_lat==[14.4034,35.8869] and data.crs=="EPSG:32633","Asset metadata preserves geographic input and the source projection")
	var hashes_ok: bool=true
	for path in data.source_hashes:
		hashes_ok=hashes_ok and FileAccess.get_sha256("res://assets/malta/"+path)==data.source_hashes[path]
	check(hashes_ok,"Terrain, all source airfield/mission coordinates and road network are byte-for-byte unchanged")
	check(data.building_count>=170 and data.buildings.any(func(b):return b.courtyard),"Dense irregular housing includes actual open courtyards")
	check(data.wall_segments>=90 and data.outline_world_xz.size()>12,"Fortified footprint has many irregular curtain-wall and bastion segments")
	check(city.layout.triangles<150000 and city.structure_count<=24 and city.detail_count<=24,"City geometry and render chunks stay within a bounded budget")
	check(city.collision_count==city.structure_count and city.collision_count>0,"Persistent simplified collision matches the solid structures")
	var visuals: Array=city.get_node("CityVisual").find_children("*","MeshInstance3D",true,false)
	var render_ok: bool=true
	for visual in visuals:
		render_ok=render_ok and visual.material_override is StandardMaterial3D and visual.material_override.vertex_color_use_as_albedo and visual.visibility_range_end==(1400 if String(visual.name).ends_with("Detail") else 14000)
	check(render_ok and not visuals.is_empty(),"Native/web StandardMaterial3D and separate near/distant detail culling are configured")
	var cathedral: Dictionary={}
	var gate: Dictionary={}
	for record in data.landmarks:
		if record.name=="St Paul's Cathedral":cathedral=record
	for record in data.portals:
		if record.name=="Mdina Main Gate":gate=record
	check(not cathedral.is_empty() and not gate.is_empty(),"Cathedral and prominent arched entrance are separate authored features")
	var wall_top: float=0
	for record in data.walls:wall_top=maxf(wall_top,float(record.top))
	check(float(cathedral.height)>wall_top+15,"Cathedral dome and towers dominate the fortified skyline")
	var excludes: Array[RID]=[]
	for node in city.get_children():
		if node is StaticBody3D:excludes.append(node.get_rid())
	var east:=city.position+Vector3(290,0,0)
	var ground_ray:=PhysicsRayQueryParameters3D.create(east+Vector3.UP*400,east,1,excludes)
	var east_hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ground_ray)
	check(not east_hit.is_empty() and float(data.reference_terrain_height)-east_hit.position.y>20,"City retains its elevated relationship to lower eastern countryside")
	var roofs: int=0
	for i in range(0,data.buildings.size(),10):
		var record: Dictionary=data.buildings[i]
		# Use a midpoint of a facade and a small inward offset; representative
		# centres can be open courtyard voids and should not hit a roof there.
		var a:=Vector2(record.footprint_xz[0][0],record.footprint_xz[0][1])
		var b:=Vector2(record.footprint_xz[1][0],record.footprint_xz[1][1])
		var centre:=Vector2(record.centre_xz[0],record.centre_xz[1])
		var xy: Vector2=(a+b)*.5
		xy=xy.move_toward(centre,.9)
		var top:=Vector3(xy.x,float(record.roof)+3,xy.y)
		var ray:=PhysicsRayQueryParameters3D.create(top,top-Vector3.UP*5,1)
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and city.is_ancestor_of(hit.collider):roofs+=1
	check(roofs>=14,"Actual building roofs block swept collision rays")
	var wall_hits: int=0
	for i in range(0,data.walls.size(),8):
		var record: Dictionary=data.walls[i]
		var a:=Vector2(record.start_xz[0],record.start_xz[1]);var b:=Vector2(record.end_xz[0],record.end_xz[1])
		var midpoint: Vector2=(a+b)*.5;var direction: Vector2=(b-a).normalized();var normal:=Vector2(direction.y,-direction.x)
		var start:=Vector3(midpoint.x+normal.x*15,float(record.top)-2,midpoint.y+normal.y*15)
		var end:=Vector3(midpoint.x-normal.x*15,float(record.top)-2,midpoint.y-normal.y*15)
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,end,1))
		if not hit.is_empty() and city.is_ancestor_of(hit.collider):wall_hits+=1
	check(wall_hits>=10,"Battered curtain walls physically block horizontal gunfire paths")
	# Check actual terrain under road stations, then a truck-sized clearance box.
	var road_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/malta/roads/world_paths.json"))
	var road_samples: int=0
	var road_blocked: int=0
	for path in road_data.paths:
		if not data.road_ids.has(path.id):continue
		for i in range(0,path.points.size(),3):
			var point:=Vector3(float(path.points[i][0]),0,float(path.points[i][1]))
			if point.distance_to(Vector3(city.position.x,0,city.position.z))>330:continue
			var ground: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*400,point,1,excludes))
			if ground.is_empty() or ground.position.y<120:continue
			var shape:=BoxShape3D.new();shape.size=Vector3(2.6,3,2.6)
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.transform=Transform3D(Basis.IDENTITY,ground.position+Vector3.UP*1.8)
			for hit in world.get_world_3d().direct_space_state.intersect_shape(query,32):
				if city.is_ancestor_of(hit.collider):
					road_blocked+=1
					print("BLOCKED ROAD ",path.id," ",ground.position," ",hit.collider.name)
			road_samples+=1
	print("MDINA ROAD STATIONS: ",road_samples," blocked=",road_blocked)
	check(road_samples>=40 and road_blocked==0,"Both existing road routes retain truck-sized physical clearance")
	var gate_point:=MaltaGeography.vector(gate.position)
	var gate_hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(gate_point+Vector3(0,2,12),gate_point+Vector3(0,2,-12),1))
	check(gate_hit.is_empty() or not city.is_ancestor_of(gate_hit.collider),"Main gate has an open physical passage rather than a solid facade")
	var pilot:=GroundPilot.new();world.add_child(pilot)
	pilot.global_position=gate_point+Vector3(0,1.05,13)
	pilot.yaw=0
	Input.action_press("throttle_up")
	await frames(660)
	Input.action_release("throttle_up")
	check(pilot.global_position.z<gate_point.z-9 and pilot.global_position.y>180 and pilot.is_on_floor(),"Existing soldier controller walks through the main arch onto the internal street")
	pilot.queue_free()
	await frames(3)
	var truck:=MilitaryTruck.new();world.add_child(truck)
	truck.global_position=gate_point+Vector3(0,.15,20)
	truck.start_driving()
	Input.action_press("throttle_up")
	await frames(480)
	Input.action_release("throttle_up")
	truck.stop_driving()
	check(truck.global_position.z<gate_point.z-8 and truck.grounded and truck.global_position.y>180,"Existing military truck drives through the gate with real vehicle collision and gravity")
	truck.queue_free()
	await frames(3)
	var markers: Array=MaltaGeography.data().landmarks.filter(func(m):return m.name=="Mdina")
	check(markers.size()==1 and MaltaGeography.vector(markers[0].position).distance_to(city.position+Vector3.UP*data.reference_terrain_height)<.05,"Navigation map gets one accurately placed Mdina marker")
	world.terrain_appearance.set_debug_heatmap(true)
	check(not city.visible and not world.valletta_city.visible and city.collision_count>0,"Terrain debug hides both cities without removing their physical structures")
	world.terrain_appearance.set_debug_heatmap(false)
	check(city.visible and world.valletta_city.visible,"Normal rendering restores both original city instances")
	check(world.fields.size()==3 and world.aa_battery.guns.size()==18 and world.trucks.size()==3,"All existing airfields, guns and military vehicles remain present")
	world.queue_free();await frames(4)
	var fresh:=MaltaWorld.new();root.add_child(fresh);await frames(4)
	check(not is_instance_valid(city) and fresh.find_children("MdinaCity","",true,false).size()==1 and fresh.find_children("VallettaCity","",true,false).size()==1,"Retry frees the old city and creates exactly one Mdina and one Valletta")
	fresh.queue_free();await frames(3)
	print("MDINA RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)
