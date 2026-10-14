extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in range(n):await physics_frame
func check(value: bool,label: String) -> void:
	if value:passed+=1;print("PASS: ",label)
	else:failed+=1;push_error("FAIL: "+label)
func release() -> void:
	for action in ["throttle_up","throttle_down","rudder_left","rudder_right","brake"]:Input.action_release(action)
func run() -> void:
	var session: Node3D=load("res://main.tscn").instantiate()
	root.add_child(session)
	await frames(8)
	session.start_malta("luqa","spitfire","interception")
	await frames(16)
	session.malta_mission.pilot.set_active(false)
	var world: MaltaWorld=session.field
	var data: Dictionary=MaltaBaseAccess.data()
	check(data.bases.size()==3,"Exactly the three existing Malta bases reuse existing exterior access links")
	for id in data.bases:
		var record: Dictionary=data.bases[id]
		var field: MaltaAirfield=world.fields[id]
		var material: ShaderMaterial=field.apron_surface.material_override
		check(material.get_shader_parameter("access_count")==4 and material.get_shader_parameter("access_half_width")==2.25,id+": four continuous 4.5 m apron lanes share the existing material/surface")
		check(field.find_children("*","StaticBody3D",true,false).size()==2,id+": no new road slabs, overlaps or colliders")
		var truck: MilitaryTruck
		for candidate in world.trucks:
			if String(candidate.name).begins_with(id):truck=candidate
		for route_id in record.routes:
			var route: Array=record.routes[route_id]
			var points: Array[Vector3]=[]
			var max_grade:=0.0
			var supported:=true
			var previous: Vector3=Vector3.INF
			for value in route:
				var ray:=PhysicsRayQueryParameters3D.create(Vector3(value[0],500,value[1]),Vector3(value[0],-5,value[1]),1,[truck.get_rid()])
				var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
				if hit.is_empty() or hit.normal.y<.85:supported=false;continue
				var point: Vector3=hit.position
				if previous.is_finite():
					var horizontal: float=((point-previous)*Vector3(1,0,1)).length()
					if horizontal>1:max_grade=maxf(max_grade,absf(point.y-previous.y)/horizontal)
				previous=point
				points.append(point)
			check(supported and max_grade<.2,id+" "+route_id+": full access has dry, gentle, continuous ground support; max grade="+str(max_grade))
			truck.global_position=points[0]+Vector3.UP*.08
			truck.velocity=Vector3.ZERO
			truck.speed=0
			truck.steering=0
			truck.look_at(Vector3(points[1].x,truck.global_position.y,points[1].z))
			truck.occupied=true
			var index:=1
			var unsupported:=0
			var ticks:=0
			for tick in range(21600):
				ticks=tick
				while index<points.size()-1 and ((points[index]-truck.global_position)*Vector3(1,0,1)).length()<7:index+=1
				var flat: Vector3=(points[index]-truck.global_position)*Vector3(1,0,1)
				if index==points.size()-1 and flat.length()<5:break
				var desired: float=atan2(-flat.x,-flat.z)
				var error: float=wrapf(desired-truck.rotation.y,-PI,PI)
				Input.action_release("rudder_left")
				Input.action_release("rudder_right")
				Input.action_press("rudder_left" if error>0 else "rudder_right",clampf(absf(error)*1.7,0,1))
				Input.action_press("throttle_up",.28 if absf(error)>.4 else .8)
				await physics_frame
				if tick>30 and not truck.grounded:unsupported+=1
				if tick%3600==0:print("DRIVE ",id," ",route_id," t=",tick/120.0," progress=",index,"/",points.size())
			release()
			Input.action_press("brake")
			await frames(60)
			release()
			truck.stop_driving()
			var arrived: bool=((truck.global_position-points.back())*Vector3(1,0,1)).length()<7
			check(arrived and unsupported<20,id+" "+route_id+": real controls drive public join → apron → gun; time="+str(ticks/120.0)+" s")
			check(session.malta_mission.interaction.find_exit(truck,2.4).is_finite(),id+" "+route_id+": clear low-speed exit near emplacement")
	check(session.malta_mission.fleet.all(func(a):return a.health.hp==100 and not a.is_crashed),"Routes keep parked aircraft unobstructed and undamaged")
	check(session.interception.phase=="CHECKPOINT" and not session.interception.activated,"Travel does not alter interception rules or activate aircraft checkpoints")
	session.queue_free()
	await frames(8)
	print("BASE ACCESS RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)
