extends SceneTree
var passed: int = 0
var failed: int = 0
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in range(n):await physics_frame
func check(ok: bool,label: String) -> void:
	if ok:passed+=1;print("PASS: ",label)
	else:failed+=1;push_error("FAIL: "+label)
func run() -> void:
	var world:=MaltaWorld.new();root.add_child(world);await frames(5)
	var region: CottoneraRegion=world.cottonera_region
	check(region.status=="partial_geodata" and region.manifest.building_count>500,"Supplied footprints populate Cottonera while incomplete historical roles remain explicit")
	check(region.regions.size()==4 and region.regions.has("birgu") and region.regions.has("senglea") and region.regions.has("bormla") and region.regions.has("kalkara"),"Four rendering groups coexist in the same continuous world")
	check(region.visual_count>0 and region.collision_count>0 and not region.find_children("*","MeshInstance3D",true,false).is_empty(),"Supplied source footprints produce real visible geometry and persistent collision")
	var physical_hit: bool=false
	for shape_node in region.find_children("*","CollisionShape3D",true,false):
		if not shape_node.shape is ConcavePolygonShape3D: continue
		var faces: PackedVector3Array=shape_node.shape.get_faces()
		for index in range(0,mini(faces.size(),300),3):
			var normal: Vector3=(faces[index+1]-faces[index]).cross(faces[index+2]-faces[index]).normalized()
			if normal.y<.8: continue
			var point: Vector3=shape_node.global_transform*((faces[index]+faces[index+1]+faces[index+2])/3)
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP*2,1))
			physical_hit=not hit.is_empty() and region.is_ancestor_of(hit.collider)
			if physical_hit: break
		if physical_hit: break
	check(physical_hit,"A real source-derived Cottonera roof physically intercepts a swept ray")
	var valid: bool=true
	for path in region.manifest.source_hashes:valid=valid and FileAccess.get_sha256("res://assets/malta/"+path)==region.manifest.source_hashes[path]
	check(valid,"Original terrain coastline road paths and gameplay-coordinate files remain byte-for-byte unchanged")
	var anchors: bool=true
	for record in region.manifest.regions:
		var node: Node3D=region.regions[record.id]
		anchors=anchors and absf(node.position.x-record.position[0])<.02 and absf(node.position.z-record.position[2])<.02 and node.position.y==0 and int(node.get_meta("geonameid"))==int(record.geonameid)
	check(anchors,"Place anchors retain gazetteer identity and do not double-apply terrain elevation")
	check(not region.show_missing_data_markers and region.find_children("*","Label3D",true,false).is_empty(),"Debug placeholder labels never masquerade as normal mapped architecture")
	var names: Array=MaltaGeography.data().landmarks.map(func(m):return m.name)
	check(names.count("Birgu (Vittoriosa)")==1 and names.count("Isla (Senglea)")==1 and names.count("Bormla (Cospicua)")==1,"Navigation gets one geographic label per settlement without duplicate city spawns")
	world.terrain_appearance.set_debug_heatmap(true)
	check(not region.visible and region.collision_count>0,"Terrain debugging hides urban visuals while retaining physical collision")
	world.terrain_appearance.set_debug_heatmap(false)
	check(region.visible and world.valletta_city.visible and world.mdina_city.visible,"Normal mode restores all existing scenery visibility")
	# Explicit synthetic render fixtures, not mapped city geography.
	var fixture:=Node3D.new();world.add_child(fixture)
	var ranges: bool=true
	for level in ["near","mid","far"]:
		var mesh:=MeshInstance3D.new();mesh.mesh=BoxMesh.new();fixture.add_child(mesh)
		region._configure(mesh,level,StandardMaterial3D.new())
		ranges=ranges and mesh.visibility_range_begin==(5000 if level=="far" else 0) and mesh.visibility_range_end==(16000 if level=="far" else (5000 if level=="mid" else 700))
	check(ranges,"Close detail, intermediate structures and distant skyline have distinct visual ranges")
	var source: Node3D=load("res://assets/malta/cottonera/templates/gate_collision.glb").instantiate()
	fixture.position=Vector3(0,500,0)
	region._collect_collision(fixture,source,Transform3D.IDENTITY);source.free();await frames(3)
	var centre:=Vector3(0,502,0)
	var through: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(centre+Vector3(0,0,10),centre-Vector3(0,0,10),1))
	check(through.is_empty(),"Unplaced gate template has a real clear passage under its arch")
	var pillar:=Vector3(5,502,0)
	var struck: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pillar+Vector3(0,0,10),pillar-Vector3(0,0,10),1))
	check(not struck.is_empty() and fixture.is_ancestor_of(struck.collider),"The same gate's masonry physically blocks swept collision rays")
	fixture.queue_free();await frames(3)
	check(world.fields.size()==3 and world.trucks.size()==3 and world.aa_battery.guns.size()==18,"Airfields vehicles and AA emplacements retain their original counts")
	world.queue_free();await frames(4)
	var fresh:=MaltaWorld.new();root.add_child(fresh);await frames(4)
	check(not is_instance_valid(region) and fresh.find_children("CottoneraRegion","",true,false).size()==1 and fresh.cottonera_region.visual_count>0 and fresh.cottonera_region.collision_count==int(fresh.cottonera_region.manifest.collision_chunks),"Retry frees old geometry and creates exactly one populated region with the expected collision count")
	fresh.queue_free();await frames(3)
	print("COTTONERA RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)
