extends SceneTree
var passed: int = 0
var failed: int = 0
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS: ",label)
	else: failed += 1; push_error("FAIL: "+label)
func run() -> void:
	var terrain_hash := FileAccess.get_sha256("res://assets/malta/terrain.glb")
	var data := FileAccess.get_file_as_string("res://assets/malta/world_data.json")
	var world := MaltaWorld.new()
	root.add_child(world)
	await frames(5)
	var city: VallettaCity = world.valletta_city
	check(city.ready_for_flight and city.layout.building_count >= 600,"Continuous Malta world contains a dense city rather than the old scattered blocks")
	check(city.position == MaltaGeography.vector(city.layout.origin_world) and city.scale == Vector3.ONE,"City uses the existing geographic marker and metre scale")
	check(terrain_hash == city.layout.terrain_sha256,"City foundations were fitted to this exact terrain resource")
	check(city.layout.wall_segments >= 90 and city.layout.landmarks.size() == 5,"City includes extensive fortifications and five original landmark silhouettes")
	var names: Array = city.layout.landmarks.map(func(record): return record.name)
	check(names.has("Fort St Elmo") and names.has("St Johns co-cathedral"),"Fort and cathedral are represented separately from ordinary housing")
	check(city.layout.triangles < 250000 and city.structure_count <= 30 and city.detail_count <= 30,"Chunking and geometry budgets keep the city bounded")
	check(city.collision_count == city.structure_count and city.collision_count > 0,"Each structure chunk has persistent simplified collision")
	var visuals := city.get_node("CityVisual").find_children("*","MeshInstance3D",true,false)
	var materials_ok := not visuals.is_empty()
	var ranges_ok := true
	for visual in visuals:
		materials_ok = materials_ok and visual.material_override is StandardMaterial3D and visual.material_override.vertex_color_use_as_albedo and visual.material_override.vertex_color_is_srgb and visual.material_override.roughness > .9
		ranges_ok = ranges_ok and visual.visibility_range_end == (1600 if String(visual.name).ends_with("Detail") else 14000)
	check(materials_ok,"Explicit native/web StandardMaterial3D uses bundled limestone colours with no shader or texture dependency")
	check(ranges_ok,"Facade details cull separately from the distant city silhouette")
	check(world.landscape_details.town_instance_count == 0,"Old provisional town blocks are removed instead of stacking cities")
	var roof_hits: int = 0
	var wall_hits: int = 0
	for i in range(0,city.layout.buildings.size(),40):
		var record: Dictionary = city.layout.buildings[i]
		var point := Vector3(float(record.centre[0]),float(record.roof),float(record.centre[1]))
		var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*5,point-Vector3.UP*4,1)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and city.is_ancestor_of(hit.collider) and absf(hit.position.y-point.y)<.15: roof_hits += 1
		# A horizontal ray crosses the actual facade at a height above local ground.
		var right := Vector3(float(city.layout.grid_forward_xz[1])*-1,0,float(city.layout.grid_forward_xz[0]))
		point.y -= 2
		ray = PhysicsRayQueryParameters3D.create(point+right*(float(record.size[0])*.5+3),point,1)
		hit = world.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and city.is_ancestor_of(hit.collider): wall_hits += 1
	check(roof_hits >= 15,"Physics rays hit building roofs at authored world-space heights")
	check(wall_hits >= 15,"Building walls block physical ray/swept projectile paths")
	world.terrain_appearance.set_debug_heatmap(true)
	check(not city.visible and city.collision_count > 0,"Heatmap hides city visuals while physical structures remain stable")
	world.terrain_appearance.set_debug_heatmap(false)
	check(city.visible,"Normal mode restores the same city without rebuilding it")
	check(world.fields.size() == 3 and world.aa_battery.guns.size() == 18,"All three airfields and existing AA placements remain present")
	check(FileAccess.get_sha256("res://assets/malta/terrain.glb") == terrain_hash and FileAccess.get_file_as_string("res://assets/malta/world_data.json") == data,"City loading leaves terrain, coastline, elevations and mission/airfield coordinates unchanged")
	world.queue_free()
	await frames(4)
	var fresh := MaltaWorld.new()
	root.add_child(fresh)
	await frames(4)
	check(not is_instance_valid(city) and fresh.find_children("VallettaCity","",true,false).size() == 1 and fresh.valletta_city.visible,"A new world owns one fresh city and frees previous scenery/collision")
	fresh.queue_free()
	await frames(3)
	print("VALLETTA RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed == 0 else 1)
