extends SceneTree
var passed: int = 0
var failed: int = 0
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func check(ok: bool, message: String) -> void:
	if ok: passed += 1; print("PASS: ",message)
	else: failed += 1; push_error("FAIL: "+message)
func run() -> void:
	var world := MaltaWorld.new()
	root.add_child(world)
	await frames(5)
	var rural: MaltaCountryside = world.countryside
	check(rural.manifest.plots.size()>500 and rural.records.size()>20,"Continuous Malta contains the baked rural plots and static batches")
	check(rural.collision_count>0 and rural.close_visuals.is_empty(),"Coarse wall collisions load independently of detailed rock visuals")
	var valid := true
	for path in rural.manifest.source_hashes: valid = valid and FileAccess.get_sha256("res://assets/malta/"+path)==rural.manifest.source_hashes[path]
	check(valid,"Protected terrain roads city and Cottonera source hashes match the original world")
	var section: Dictionary = rural.manifest.sections[rural.manifest.sections.size()/2]
	var a := MaltaGeography.vector(section.a)
	var b := MaltaGeography.vector(section.b)
	var middle := (a+b)/2 + Vector3.UP*.2
	var normal := Vector3(b.z-a.z,0,a.x-b.x).normalized()
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(middle+normal*2,middle-normal*2,1))
	check(not hit.is_empty() and rural.is_ancestor_of(hit.collider),"Actual rural rubble-wall collision blocks a ground-height swept ray")
	var camera := Camera3D.new(); world.add_child(camera); camera.make_current()
	var record: Dictionary
	for candidate in rural.records:
		if candidate.data.files.has("near"): record=candidate; break
	camera.global_position = MaltaGeography.vector(record.data.centre)+Vector3.UP*2
	for i in range(120):
		rural.refresh_detail(camera.global_position)
		await process_frame
		if not rural.close_visuals.is_empty(): break
	check(not rural.close_visuals.is_empty(),"Approaching an agricultural chunk streams real detailed rock geometry")
	check(rural.pending.size()<=2 and rural.close_visuals.size()<=rural.maximum_close_batches,"Asynchronous close-detail queues and active batches respect fixed budgets")
	var physics_count := rural.collision_count
	camera.global_position=Vector3(100000,1000,100000)
	for i in range(10): rural.refresh_detail(camera.global_position); await process_frame
	check(rural.close_visuals.is_empty() and rural.collision_count==physics_count,"Leaving fields unloads close visuals while preserving collision and the continuous terrain")
	world.terrain_appearance.set_debug_heatmap(true)
	check(not rural.visible and rural.collision_count>0,"Terrain heatmap hides rural rendering without removing physical walls")
	world.terrain_appearance.set_debug_heatmap(false)
	check(rural.visible and world.fields.size()==3 and world.aa_battery.guns.size()==18,"Normal mode restores countryside and all military airfields/AA counts remain intact")
	world.queue_free(); await frames(4)
	var next := MaltaWorld.new(); root.add_child(next); await frames(4)
	check(not is_instance_valid(rural) and next.find_children("MaltaCountryside","",true,false).size()==1,"Full retry replaces the countryside once without duplicate scenery or collision")
	next.queue_free(); await frames(4)
	print("COUNTRYSIDE RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)
