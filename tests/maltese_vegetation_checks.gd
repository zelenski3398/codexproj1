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
	var world:=MaltaWorld.new();root.add_child(world);await frames(8)
	var trees: MalteseTrees=world.landscape_details.trees
	var expected_indices: Array[int] = []
	for i in trees.layout.trees.size():
		var point := MaltaGeography.vector(trees.layout.trees[i].position)
		if not MostaVillage.replaces_scenery(point) and not WartimeVillages.replaces_scenery(point):
			expected_indices.append(i)
	var planted_indices: Array[int] = []
	for cell in trees.placement_cells.values():
		planted_indices.append_array(cell)
	planted_indices.sort()
	check(planted_indices == expected_indices and trees.instance_count == expected_indices.size(),
		"Trunk placement preserves exactly the baked trees outside village exclusions")
	check(trees.instance_count > 2500 and trees.instance_count < trees.layout.trees.size(),
		"Malta retains substantial vegetation and clears overlapping village plots")
	check(trees.meshes.size()==18 and trees.batch_count>0,"All nine species variants use shared near/far meshes and MultiMesh batches")
	check(trees.material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and trees.material.vertex_color_use_as_albedo,"Foliage uses one shared opaque Compatibility material")
	var batch_ok:=true
	var rendered_instances := 0
	for child in trees.get_children():
		if child is MultiMeshInstance3D:
			rendered_instances += child.multimesh.instance_count
			batch_ok=batch_ok and child.multimesh.mesh!=null and child.visibility_range_end<=trees.far_distance
			for i in child.multimesh.instance_count:
				var pose: Transform3D=child.multimesh.get_instance_transform(i)
				batch_ok=batch_ok and pose.basis.y.normalized().dot(Vector3.UP)>.999
	check(batch_ok,"Trees remain upright on slopes and every visual batch has bounded range")
	check(rendered_instances == expected_indices.size() * 2, "Both visual LODs contain one instance for each retained placement")
	var record: Dictionary=trees.layout.trees[expected_indices[0]];var position:=MaltaGeography.vector(record.position)
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current();camera.global_position=position+Vector3(0,2,5)
	trees.refresh_collisions(camera.global_position);await frames(3)
	check(trees.collider_count>0 and trees.collider_count<=trees.maximum_colliders,"Nearby simple trunk colliders obey the strict active-body cap")
	var hit:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(position+Vector3(-2,1,0),position+Vector3(2,1,0),1))
	check(not hit.is_empty() and trees.is_ancestor_of(hit.collider),"Real trunk collision blocks a ground-height swept query")
	var shapes_ok:=true
	for body in trees.collision_bodies.values():shapes_ok=shapes_ok and body.get_child_count()==1 and body.get_child(0).shape is CylinderShape3D
	check(shapes_ok,"No branch or leaf physics bodies are created")
	trees.refresh_collisions(Vector3(100000,10000,100000));await frames(3)
	check(trees.collider_count==0,"Distant trunk bodies unload without changing terrain or aircraft physics")
	world.terrain_appearance.set_debug_heatmap(true);check(not trees.is_visible_in_tree(),"Heatmap debug hides tree rendering with the existing landscape owner")
	world.terrain_appearance.set_debug_heatmap(false);check(trees.is_visible_in_tree() and world.fields.size()==3 and world.aa_battery.guns.size()==18,"Normal mode restores trees and all protected airfields/AA remain")
	var count:=trees.instance_count;world.queue_free();await frames(5)
	var next:=MaltaWorld.new();root.add_child(next);await frames(8)
	check(not is_instance_valid(trees) and next.landscape_details.trees.instance_count==count,"Retry reproduces the same planting once, with no duplicate vegetation")
	next.queue_free();await frames(5)
	print("VEGETATION RUNTIME RESULT: %d/%d passed"%[passed,passed+failed]);quit(1 if failed else 0)
