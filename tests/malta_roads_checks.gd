extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	if value: passed+=1;print("PASS: ",label)
	else: failed+=1;push_error("FAIL: "+label)
func frames(n: int) -> void:
	for i in range(n): await physics_frame
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/malta/roads/world_paths.json"))
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/malta/roads/generation_report.json"))
	var world := MaltaWorld.new()
	root.add_child(world)
	await frames(12)
	check(world.mesh_count==36+int(report.terrain_chunks),"Original islands plus spatially culled terrain patches form one world")
	var coverage := 0
	var chunks := 0
	for mesh in world.terrain_appearance.meshes:
		if String(mesh.name).begins_with("RoadGround"):
			chunks+=1
			var arrays: Array=mesh.mesh.surface_get_arrays(0)
			var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			for value in uv:
				if value.x>.9: coverage+=1
	check(chunks==int(report.terrain_chunks) and coverage>1000,"Imported road patches carry bundled, opaque road coverage buffers")
	var inferred := 0
	var widths := true
	var hits := 0
	var samples := 0
	for path in data.paths:
		widths=widths and float(path.width)>=4.0 and float(path.width)<=5.0
		if path.inferred: inferred+=1
		for i in range(0,path.points.size(),maxi(1,int(path.points.size()/12))):
			var point: Array=path.points[i]
			var query:=PhysicsRayQueryParameters3D.create(Vector3(point[0],500,point[1]),Vector3(point[0],-1,point[1]),1)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			samples+=1
			if not hit.is_empty() and hit.position.y>0: hits+=1
	check(widths,"Editable roads use metre-scale 4–5 m widths")
	check(inferred==3,"All three bases have explicitly labelled short inferred access links")
	check(float(hits)/samples>.95,"Reference main-route samples are supported by land collision")
	var coordinates:=true
	for record in MaltaGeography.data().airfields:
		var field: MaltaAirfield=world.fields[record.id]
		coordinates=coordinates and absf(field.global_position.x-float(record.position[0]))<.001 and absf(field.global_position.z-float(record.position[2]))<.001
	check(coordinates,"Roads do not move airfields or alter geographic coordinates")
	check(report.registration.leave_one_out_rms_metres>0 and not report.uncertainties.is_empty(),"Reference distortion and omitted/uncertain sections are explicitly recorded")
	for path in data.paths:
		if not path.inferred: continue
		var field_id: String=String(path.id).trim_prefix("access_")
		var truck: MilitaryTruck=null
		for candidate in world.trucks:
			if String(candidate.name).begins_with(field_id):truck=candidate
		var p: Array=path.points[0]
		var n: Array=path.points[1]
		var ray:=PhysicsRayQueryParameters3D.create(Vector3(p[0],500,p[1]),Vector3(p[0],0,p[1]),1)
		var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
		truck.global_position=hit.position+Vector3.UP*.08
		truck.look_at(truck.global_position+Vector3(n[0]-p[0],0,n[1]-p[1]))
		truck.velocity=Vector3.ZERO
		truck.speed=0
		var start: Vector3=truck.global_position
		truck.occupied=true
		Input.action_press("throttle_up")
		var unsupported:=0
		for tick in range(900):
			await physics_frame
			if tick>60 and not truck.grounded:unsupported+=1
		Input.action_release("throttle_up")
		truck.stop_driving()
		check(truck.global_position.distance_to(start)>60 and unsupported<12,field_id+": physical truck drives from base onto access road without a step or unsupported drop")
	world.terrain_appearance.set_debug_heatmap(true)
	check(world.terrain_appearance.debug_heatmap_enabled,"Terrain road coverage supports deliberate heatmap debug without changing physics")
	world.queue_free()
	await frames(3)
	print("MALTA ROADS RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)
