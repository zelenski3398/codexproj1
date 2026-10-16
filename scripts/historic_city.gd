class_name HistoricCity
extends Node3D
## Additive, metre-scale city fitted offline to the existing Malta terrain.
## Chunked imported meshes have native mesh LODs; only structure gets collision.
var layout_path: String
var city_name: String
var visual_scene: PackedScene
var collision_scene: PackedScene
var detail_distance: float = 1600
var structure_distance: float = 14000
var layout: Dictionary
var structure_count: int = 0
var detail_count: int = 0
var collision_count: int = 0
var ready_for_flight: bool = false

func _ready() -> void:
	name = city_name
	layout = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
	position = MaltaGeography.vector(layout.origin_world)
	var visual: Node3D = visual_scene.instantiate()
	visual.name = "CityVisual"
	add_child(visual)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.72, 0.72, 0.72)
	material.vertex_color_use_as_albedo = true
	# Palette bytes were authored as sRGB, not linear light.
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	_prepare_visual(visual, material)
	# A separate coarse source excludes windows, balconies and parapet trim.
	# These static BVHs remain loaded, so bullets, aircraft and ground players
	# encounter the same walls even when distant visual details are culled.
	var source: Node3D = collision_scene.instantiate()
	_build_collision(source)
	source.free()
	ready_for_flight = true

func _prepare_visual(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		var item: MeshInstance3D = node
		var detail: bool = String(item.name).ends_with("Detail")
		item.material_override = material
		item.visibility_range_end = detail_distance if detail else structure_distance
		item.visibility_range_end_margin = 150 if detail else 1500
		item.lod_bias = 0.6
		# Native/web Compatibility renderer: no custom shader/textures needed.
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if detail else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if detail: detail_count += 1
		else: structure_count += 1
	for child in node.get_children():
		_prepare_visual(child, material)

func _build_collision(node: Node3D, pose: Transform3D = Transform3D.IDENTITY) -> void:
	var composed: Transform3D = pose * node.transform
	if node is MeshInstance3D:
		var body := StaticBody3D.new()
		body.name = "CitySolid_%d" % collision_count
		body.collision_layer = 1
		body.collision_mask = 0
		add_child(body)
		body.transform = composed
		var shape := CollisionShape3D.new()
		shape.shape = node.mesh.create_trimesh_shape()
		body.add_child(shape)
		collision_count += 1
	for child in node.get_children():
		if child is Node3D: _build_collision(child, composed)
