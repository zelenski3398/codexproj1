extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	if value: passed+=1;print("PASS: ",label)
	else: failed+=1;push_error("FAIL: "+label)
func frames(n: int) -> void:
	for i in range(n): await physics_frame
func ground(world: Node3D,point: Vector3) -> Dictionary:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*100,point-Vector3.UP*100,1))
func run() -> void:
	var world := MaltaWorld.new()
	root.add_child(world)
	await frames(12)
	for field in world.fields.values():
		var max_error := 0.0
		for z in [-field.runway_length*.49,0.0,field.runway_length*.49,field.runway_length*.31]:
			for x in [-26.0,0.0,26.0]:
				var expected: Vector3 = field.to_global(Vector3(x,0,z))
				var hit := ground(world,expected)
				if hit.is_empty(): max_error=INF
				else: max_error=maxf(max_error,absf(hit.position.y-expected.y))
		check(max_error<0.04,field.record.id+": runway terrain matches graded surface within 4 cm; max="+str(max_error))
		var apron_error := 0.0
		for x in [20.0,60.0,105.0]:
			for z in [-110.0,0.0,110.0]:
				var point: Vector3=field.to_global(Vector3(x,0,field.runway_length*.31+z))
				var hit:=ground(world,point)
				apron_error=maxf(apron_error,absf(hit.position.y-point.y) if not hit.is_empty() else INF)
		check(apron_error<0.04,field.record.id+": apron, parking and base grounds continuously supported")
		check(field.find_children("*","StaticBody3D",true,false).size()==2,field.record.id+": only hangars collide; no overlapping runway/apron platforms")
		var crossings := true
		var previous := 0.0
		for step in range(61):
			var x := -70.0+step*2.0
			var point: Vector3=field.to_global(Vector3(x,0,field.runway_length*.31))
			var hit:=ground(world,point)
			if hit.is_empty(): crossings=false;continue
			if step>0 and absf(hit.position.y-previous)>0.45: crossings=false
			previous=hit.position.y
		check(crossings,field.record.id+": adjacent land/runway/apron boundary has no drops or steps")
		for building in field.installations:
			check(building.global_basis.y.dot(Vector3.UP)>.99999,field.record.id+": building remains upright")
	for gun in world.aa_battery.guns:
		var hit:=ground(world,gun.global_position+Vector3(5,0,0))
		check(not hit.is_empty() and absf(hit.position.y-gun.global_position.y)<.12,gun.name+": accessible grounded AA emplacement")
	for truck in world.trucks:
		check(truck.grounded,truck.name+": wheels/body supported by edited terrain")
	print("AIRFIELD GROUND RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)
