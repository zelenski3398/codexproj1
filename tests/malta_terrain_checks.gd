extends SceneTree
## Real imported buffers, active materials, terrain colliders and debug input.
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var source: Node3D = preload("res://assets/malta/terrain.glb").instantiate()
	var original: Array[MeshInstance3D] = []
	_collect(source, original)
	var source_data: Array = _snapshot(original)
	var original_materials: Array = []
	for mesh in original:
		original_materials.append(mesh.mesh.surface_get_material(0))
	var world: MaltaWorld = MaltaWorld.new()
	root.add_child(world)
	await _frames(3)
	var appearance: MaltaTerrainAppearance = world.terrain_appearance
	_check(original.size() == 36 and appearance.meshes.size() == 36, "All 36 supplied island meshes receive the explicit terrain material")
	_check(not appearance.debug_heatmap_enabled and not appearance.debug_notice.visible, "A fresh Malta world defaults to normal mode without a debug notice")
	_check(_all_materials(appearance, MaltaTerrainAppearance.LIMESTONE), "Every active surface uses the shared limestone resource")
	_check(not MaltaTerrainAppearance.LIMESTONE.vertex_color_use_as_albedo and MaltaTerrainAppearance.LIMESTONE.albedo_texture == null, "Normal mode ignores embedded colours and has no texture dependency")
	_check(MaltaTerrainAppearance.LIMESTONE.albedo_color.r > MaltaTerrainAppearance.LIMESTONE.albedo_color.b and MaltaTerrainAppearance.LIMESTONE.metallic == 0 and MaltaTerrainAppearance.LIMESTONE.roughness == 1, "Limestone is beige, matte and nonmetallic")
	_check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility", "Terrain uses the project's existing Compatibility renderer")
	_check(_snapshot(appearance.meshes) == source_data, "Override leaves imported vertices, indices, vertex colours, transforms and bounds unchanged")
	var collider_data: Array = _colliders(appearance.meshes)
	_check(collider_data.size() == 36, "All 36 existing static terrain collider shapes are retained")
	_check(world.fields.luqa.record.position == MaltaGeography.field("luqa").position and world.fields.ta_qali.record.position == MaltaGeography.field("ta_qali").position and world.fields.hal_far.record.position == MaltaGeography.field("hal_far").position, "All three airfields retain the original geography records")
	_key(KEY_F4, true)
	await _frames(3)
	_check(appearance.debug_heatmap_enabled and appearance.debug_notice.visible, "Explicit F4 press enables and labels elevation heatmap debug")
	_check(_all_materials(appearance, MaltaTerrainAppearance.HEATMAP), "Debug mode uses a single explicit heatmap material on all islands")
	_check(MaltaTerrainAppearance.HEATMAP.vertex_color_use_as_albedo and not MaltaTerrainAppearance.HEATMAP.vertex_color_is_srgb and MaltaTerrainAppearance.HEATMAP.albedo_texture == null, "Debug reads original COLOR_0 using the previous import colour interpretation")
	_check(_snapshot(appearance.meshes) == source_data and _colliders(appearance.meshes) == collider_data, "Enabling debug cannot change geometry, transforms or terrain collision")
	_key(KEY_F4, true, true)
	_check(appearance.debug_heatmap_enabled, "OS key repeat cannot flicker debug mode")
	_key(KEY_F4, false)
	_key(KEY_F4, true, false, true)
	_key(KEY_F4, false, false, true)
	await _frames(3)
	_check(not appearance.debug_heatmap_enabled and _all_materials(appearance, MaltaTerrainAppearance.LIMESTONE), "Keycode-only embedded input returns every surface to limestone")
	paused = true
	_key(KEY_F4, true)
	_key(KEY_F4, false)
	for frame in range(3):
		await process_frame
	_check(paused and appearance.debug_heatmap_enabled, "Render debug works during pause without resuming physics")
	_key(KEY_F4, true)
	_key(KEY_F4, false)
	for frame in range(3):
		await process_frame
	_check(paused and not appearance.debug_heatmap_enabled, "Paused debug can be explicitly switched off")
	paused = false
	_check(_snapshot(appearance.meshes) == source_data and _colliders(appearance.meshes) == collider_data, "Round trip preserves every protected terrain buffer and collider")
	var untouched: bool = true
	for i in range(original.size()):
		untouched = untouched and original[i].mesh.surface_get_material(0) == original_materials[i]
	_check(untouched, "Shared imported resources are never mutated by material switching")
	world.queue_free()
	source.free()
	await _frames(3)
	var fresh: MaltaWorld = MaltaWorld.new()
	root.add_child(fresh)
	await _frames(3)
	_check(not fresh.terrain_appearance.debug_heatmap_enabled and _all_materials(fresh.terrain_appearance, MaltaTerrainAppearance.LIMESTONE), "A new mission never inherits debug mode from an earlier world")
	fresh.queue_free()
	await _frames(3)
	print("MALTA TERRAIN RESULT: ", checks - failures, "/", checks, " passed")
	quit(1 if failures else 0)

func _collect(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		_collect(child, meshes)

func _snapshot(meshes: Array[MeshInstance3D]) -> Array:
	var result: Array = []
	for node in meshes:
		var surfaces: Array = []
		for i in range(node.mesh.get_surface_count()):
			surfaces.append(hash(node.mesh.surface_get_arrays(i)))
		result.append([node.name, node.transform, node.mesh.get_aabb(), surfaces])
	return result

func _colliders(meshes: Array[MeshInstance3D]) -> Array:
	var result: Array = []
	for mesh in meshes:
		for body in mesh.get_children():
			if body is StaticBody3D:
				for shape in body.get_children():
					if shape is CollisionShape3D and shape.shape is ConcavePolygonShape3D:
						result.append([body.get_instance_id(), shape.get_instance_id(), hash(shape.shape.get_faces()), body.transform, shape.transform])
	return result

func _all_materials(appearance: MaltaTerrainAppearance, expected: Material) -> bool:
	for mesh in appearance.meshes:
		for surface in range(mesh.mesh.get_surface_count()):
			if mesh.get_active_material(surface) != expected:
				return false
	return true

func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame

func _key(code: int, pressed: bool, echo: bool = false, keycode_only: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	if keycode_only:
		event.keycode = code
	else:
		event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
