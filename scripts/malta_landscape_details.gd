class_name MaltaLandscapeDetails
extends Node3D
## Decorative only: no collision, gameplay ownership or persistent-state changes.
## Valletta buildings are owned separately by VallettaCity.
var world: MaltaWorld
var instance_count: int = 0
var batch_count: int = 0
var town_instance_count: int = 0

func _ready() -> void:
	name = "MaltaLandscapeDetails"
	call_deferred("_populate")

func _populate() -> void:
	# Static collision must have reached the physics server before alignment rays.
	await get_tree().physics_frame
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/malta/landscape/decoration.json"))
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = int(layout.seed)
	var batches: Dictionary = {}
	for centre in layout.scrub_centres:
		for plant in range(4):
			var point: Vector3 = Vector3(float(centre[0]) + random.randf_range(-12, 12), 0, float(centre[1]) + random.randf_range(-12, 12))
			var hit: Dictionary = _ground(point)
			# New city roofs are physical ground hits, but never planting sites.
			if not hit.is_empty() and (world.valletta_city.is_ancestor_of(hit.collider) or world.mdina_city.is_ancestor_of(hit.collider) or world.cottonera_region.is_ancestor_of(hit.collider)):
				continue
			if hit.is_empty() or hit.position.y < 2 or hit.normal.y < 0.8:
				continue
			var size: float = random.randf_range(0.65, 1.3)
			var pose: Transform3D = Transform3D(Basis(Vector3.UP, random.randf_range(0, TAU)).scaled(Vector3.ONE * size), hit.position + Vector3.UP * size)
			var key: Vector2i = Vector2i(floori(point.x / 2500), floori(point.z / 2500))
			if not batches.has(key):
				batches[key] = []
			batches[key].append(pose)
	var bush: CylinderMesh = CylinderMesh.new()
	bush.height = 2.0
	bush.top_radius = 0.65
	bush.bottom_radius = 1.6
	bush.radial_segments = 6
	bush.rings = 1
	bush.material = MeshKit.material(Color(0.18, 0.205, 0.115), 1.0)
	for key in batches:
		_batch(bush, batches[key], 1700)
	visible = not world.terrain_appearance.debug_heatmap_enabled

func _ground(point: Vector3) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(point.x, 1000, point.z), Vector3(point.x, -40, point.z), 1)
	return get_world_3d().direct_space_state.intersect_ray(query)

func _batch(mesh: Mesh, poses: Array, distance: float) -> void:
	if poses.is_empty():
		return
	# Centre each batch locally so distance culling uses its actual region.
	var origin: Vector3 = poses[0].origin
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = poses.size()
	for i in range(poses.size()):
		var local: Transform3D = poses[i]
		local.origin -= origin
		multimesh.set_instance_transform(i, local)
	var item: MultiMeshInstance3D = MultiMeshInstance3D.new()
	item.multimesh = multimesh
	item.position = origin
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	item.visibility_range_end = distance
	item.visibility_range_end_margin = 100
	add_child(item)
	instance_count += poses.size()
	batch_count += 1
