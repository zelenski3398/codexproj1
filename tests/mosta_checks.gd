extends SceneTree

var passed: int
var failed: int

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, description: String) -> void:
	if value: passed += 1
	else: failed += 1
	print(("PASS " if value else "FAIL ") + description)

func _run() -> void:
	var world := MaltaWorld.new()
	root.add_child(world)
	for i in 10: await physics_frame
	var site := world.mosta_village
	if not site.ready_for_flight:
		check(false,"Mosta builds through the normal Malta world")
		quit(1)
		return
	var layout := MostaVillage.layout()
	var point := site.rotunda.global_position
	check(absf(point.x-2328.88835)<.015 and absf(point.z-2222.78755)<.015,"Rotunda is centred at projected WGS84 anchor")
	check(point.y > 40 and point.y < 160, "Rotunda samples the existing terrain height")
	check(absf(float(layout.facade_bearing_clockwise_from_north)-164.67)<.1 and site.rotunda.global_basis.z.z > .9,"The mapped forecourt faces south-southeast")
	check(site.rotunda.find_children("IonicColumn*","MeshInstance3D",false,false).size() == 6 and site.rotunda.get_node_or_null("BellTowerWest") != null and site.rotunda.get_node_or_null("BellTowerEast") != null,"Photographic portico has six pillars and paired towers")
	check(site.rotunda.find_children("DomeBand*","MeshInstance3D",false,false).size() == 19 and site.rotunda.get_node_or_null("Lantern") != null,"Stepped dome and lantern are present")
	check(layout.controls.size() == 3 and layout.road_ties.size() == 2 and layout.streets.size() == 17,"Three external alignment points and two island connections are recorded")
	check(site.house_positions.size() > 900 and site.skipped_plots < 90 and layout.outline.size() > 1, "Compact core and separate developed branches fit this terrain")
	var clear := true
	for area in layout.gaps:
		var polygon := MostaVillage._polygon(area)
		for house in site.house_positions.values():
			if Geometry2D.is_point_in_polygon(Vector2(house.x,house.z),polygon): clear = false
	check(clear and layout.gaps.size() >= 7,"Agricultural gaps and gardens remain free of houses")
	var id := String(site.house_positions.keys()[0])
	var house: Vector3 = site.to_global(site.house_positions[id])
	var query := PhysicsRayQueryParameters3D.create(house + Vector3.UP * 35, house - Vector3.UP * 12, 1)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and site.is_ancestor_of(hit.collider),"Ordinary world ray queries see Mosta roof collision")
	check(site.draw_batches < 165 and site.collision_count == site.house_positions.size() and site.damageable_count >= 10,"Building massing is batched with simplified collision and sample damage receivers")
	var sections := get_nodes_in_group("bomb_structure_sections").filter(func(section): return String(section.section_id).begins_with("mosta_"))
	check(not sections.is_empty() and sections[0].apply_blast(15,sections[0].global_position) == 15 and sections[0].hp < sections[0].maximum_hp,"Selected Mosta sections accept shared structural damage")
	check(MostaVillage.replaces_scenery(point) and not MostaVillage.replaces_scenery(point + Vector3(0,0,-1200)),"Procedural exclusions protect the village but stop before distant countryside")
	check(world.countryside.mosta_removed_collision_triangles > 0,"Overlapping original rural wall faces are removed from collision")
	world.terrain_appearance.set_debug_heatmap(true)
	check(not site.visible,"Mosta follows the existing terrain heatmap visibility mode")
	print("Mosta build usec %d · %d houses · %d batches · %d collision triangles excluded" % [site.construction_usec,site.house_positions.size(),site.draw_batches,world.countryside.mosta_removed_collision_triangles])
	print("MOSTA RESULT: %d/%d passed" % [passed,passed+failed])
	quit(1 if failed else 0)
