extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := MaltaWorld.new()
	root.add_child(world)
	for i in 50:
		await physics_frame
	var districts := world.wartime_villages.districts
	var layout := WartimeVillages.layout()
	_check(districts.size() == 22 and layout.existing.size() == 2, "22 districts plus existing Mosta and Mdina")
	_check(is_instance_valid(world.mosta_village.rotunda) and is_instance_valid(world.mdina_city), "Existing Rotunda and citadel are instantiated")
	_check(world.fields.size() == 3 and world.trucks.size() == 3, "Airfields and truck spawns are intact")
	var expected := 0
	var loaded := 0
	var lots := 0
	var batches := 0
	var skipped := 0
	var max_ms := 0.0
	var wrong_pivots := 0
	var unsafe_terrain := 0
	var land := get_root().world_3d.direct_space_state
	for record in layout.sites:
		var district: WartimeDistrict = districts.get(record.id)
		if district == null:
			continue
		expected += record.churches.size()
		loaded += district.churches.size()
		lots += district.house_positions.size()
		batches += district.draw_batches
		skipped += district.skipped_plots
		max_ms = maxf(max_ms, district.construction_usec / 1000.0)
		for model in record.churches:
			var church: WartimeChurch = district.churches.get(model.id)
			if church == null:
				continue
			var p := church.global_position
			var q := Vector2(model.center_world[0], model.center_world[1])
			if Vector2(p.x, p.z).distance_to(q) > .04 or absf(church.rotation_degrees.y - float(model.yaw_deg)) > .05:
				wrong_pivots += 1
			var ray := PhysicsRayQueryParameters3D.create(p + Vector3.UP * .02, p - Vector3.UP * (church.foundation_depth + 1), 1)
			ray.exclude.assign(church.get_children().filter(func(node): return node is StaticBody3D).map(func(node): return node.get_rid()))
			if land.intersect_ray(ray).is_empty():
				unsafe_terrain += 1
			if not WartimeVillages.replaces_scenery(p):
				unsafe_terrain += 1
	_check(expected >= 40 and loaded == expected, "All %d registered church models load" % expected)
	_check(wrong_pivots == 0, "Churches use their registry footprint pivots and orientations")
	_check(unsafe_terrain == 0, "Church foundations intersect the terrain and replace local scenery")
	_check(lots > 3500 and batches < lots and skipped < lots / 13, "Districts batch over 3,500 terrain-seated buildings")
	_check(WartimeVillages.recovery_street_points().size() > 1000, "Transport recovery samples the historical roads")
	_check(districts.st_andrews.house_positions.size() >= 6 and districts.pembroke.house_positions.size() >= 6, "Both military compounds have barracks")
	print("MEASURED lots=%d terrain_skips=%d batches=%d largest_district_ms=%.1f" % [lots, skipped, batches, max_ms])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failures += 1
