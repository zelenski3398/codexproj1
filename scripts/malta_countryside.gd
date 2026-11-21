class_name MaltaCountryside
extends Node3D
## Baked rural scenery over the existing terrain. Only close visual rocks stream;
## simple static collisions and continuous island physics remain loaded.
const MANIFEST := "res://assets/malta/countryside/manifest.json"
var manifest: Dictionary
var records: Array = []
var close_visuals: Dictionary = {}
var pending: Dictionary = {}
var collision_count: int = 0
var visual_count: int = 0
var elapsed: float = 0
var stone_material: ShaderMaterial
var mosta_removed_collision_triangles: int
var soil_material: ShaderMaterial
@export var detail_distance: float = 530
@export var unload_distance: float = 900
@export var maximum_close_batches: int = 6

func _ready() -> void:
	name = "MaltaCountryside"
	manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	stone_material = ShaderMaterial.new()
	stone_material.shader = preload("res://assets/malta/materials/countryside_stone.gdshader")
	soil_material = ShaderMaterial.new()
	soil_material.shader = preload("res://assets/malta/materials/countryside_soil.gdshader")
	soil_material.set_shader_parameter("surface_detail", preload("res://assets/malta/landscape/surface_detail.png"))
	var mosta := MostaVillage.layout()
	var mask_min := Vector2(float(mosta.mask_world_min[0]), float(mosta.mask_world_min[1]))
	for material in [stone_material,soil_material]:
		material.set_shader_parameter("mosta_scenery_mask",preload("res://assets/malta/mosta/scenery_mask.png"))
		material.set_shader_parameter("mosta_mask_min",mask_min)
		material.set_shader_parameter("mosta_mask_span",float(mosta.mask_span))
	for record in manifest.chunks:
		var chunk := Node3D.new()
		chunk.name = "Farm_%d_%d" % [record.origin[0], record.origin[2]]
		chunk.position = MaltaGeography.vector(record.origin)
		add_child(chunk)
		records.append({"data": record, "node": chunk})
		for kind in ["soil", "track", "mid", "far"]:
			if record.files.has(kind): _visual(chunk, load(record.files[kind]), kind)
		if record.files.has("collision"):
			var source: Node3D = load(record.files.collision).instantiate()
			_collision(chunk, source, Transform3D.IDENTITY)
			source.free()

func _visual(parent: Node3D, scene: PackedScene, kind: String) -> Node3D:
	var node: Node3D = scene.instantiate()
	parent.add_child(node)
	_configure(node, kind)
	return node

func _configure(node: Node, kind: String) -> void:
	if node is MeshInstance3D:
		node.material_override = soil_material if kind in ["soil", "track"] else stone_material
		node.visibility_range_begin = 0 if kind in ["soil", "track", "near"] else (160 if kind == "mid" else 2500)
		node.visibility_range_end = 13000 if kind in ["soil", "track"] else (160 if kind == "near" else (2500 if kind == "mid" else 8000))
		node.visibility_range_end_margin = 20
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual_count += 1
	for child in node.get_children(): _configure(child, kind)

func _collision(parent: Node3D, source: Node3D, pose: Transform3D) -> void:
	var transform := pose * source.transform
	if source is MeshInstance3D:
		var body := StaticBody3D.new()
		body.name = "RubbleWallCollision"
		body.collision_layer = 1
		body.collision_mask = 0
		parent.add_child(body)
		body.transform = transform
		var shape := CollisionShape3D.new()
		shape.shape = _wall_collision_shape(source.mesh, parent.global_transform * transform)
		body.add_child(shape)
		collision_count += 1
	for child in source.get_children():
		if child is Node3D: _collision(parent, child, transform)

func _wall_collision_shape(mesh: Mesh, pose: Transform3D) -> Shape3D:
	var box := pose * mesh.get_aabb()
	var anchor := MostaVillage.anchor()
	var near_site := AABB(anchor - Vector3(960,20,960),Vector3(1920,400,1920))
	if not box.intersects(near_site): return mesh.create_trimesh_shape()
	var faces := mesh.get_faces()
	var retained := PackedVector3Array()
	for i in range(0,faces.size(),3):
		var center := pose * ((faces[i]+faces[i+1]+faces[i+2])/3.0)
		if MostaVillage.replaces_scenery(center):
			mosta_removed_collision_triangles += 1
			continue
		retained.append(faces[i])
		retained.append(faces[i+1])
		retained.append(faces[i+2])
	if retained.is_empty(): return null
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(retained)
	return shape

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < .25: return
	elapsed = 0
	var camera := get_viewport().get_camera_3d()
	if camera != null: refresh_detail(camera.global_position)

func refresh_detail(listener: Vector3) -> void:
	# Keep pending loads bounded; the main thread only instantiates completed
	# resources. Terrain/collision never unload and aircraft physics never waits.
	for index in pending.keys():
		var path: String = pending[index]
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var resource: PackedScene = ResourceLoader.load_threaded_get(path)
			pending.erase(index)
			if listener.distance_to(MaltaGeography.vector(records[index].data.centre)) < unload_distance and close_visuals.size() < maximum_close_batches:
				close_visuals[index] = _visual(records[index].node, resource, "near")
		elif status == ResourceLoader.THREAD_LOAD_FAILED: pending.erase(index)
	for index in close_visuals.keys():
		if listener.distance_to(MaltaGeography.vector(records[index].data.centre)) > unload_distance:
			close_visuals[index].queue_free()
			close_visuals.erase(index)
	var candidates: Array = []
	for index in range(records.size()):
		if not records[index].data.files.has("near") or close_visuals.has(index) or pending.has(index): continue
		var distance := listener.distance_to(MaltaGeography.vector(records[index].data.centre))
		if distance < detail_distance: candidates.append({"index":index,"distance":distance})
	candidates.sort_custom(func(a,b): return a.distance < b.distance)
	for candidate in candidates:
		if pending.size() >= 2: break
		if close_visuals.size() + pending.size() >= maximum_close_batches:
			var farthest: int = -1
			var far_distance: float = 0
			for index in close_visuals:
				var distance := listener.distance_to(MaltaGeography.vector(records[index].data.centre))
				if distance > far_distance: far_distance=distance; farthest=index
			if farthest < 0 or far_distance < candidate.distance + 80: continue
			close_visuals[farthest].queue_free()
			close_visuals.erase(farthest)
		var path: String = records[candidate.index].data.files.near
		if ResourceLoader.load_threaded_request(path, "PackedScene") == OK: pending[candidate.index] = path

func _exit_tree() -> void:
	# Consume at most two small outstanding scenery loads on world disposal.
	# Ordinary flying/travel never waits for a resource or unloads physics.
	for path in pending.values(): ResourceLoader.load_threaded_get(path)
	pending.clear()
