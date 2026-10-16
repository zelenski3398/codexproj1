class_name CottoneraRegion
extends Node3D
## Source-gated Three Cities region. Empty data NEVER spawn invented geography.
const MANIFEST: String = "res://assets/malta/cottonera/region.json"
var manifest: Dictionary
var regions: Dictionary = {}
var collision_count: int = 0
var visual_count: int = 0
var status: String = "awaiting_geodata"
var show_missing_data_markers: bool = false

func _ready() -> void:
	name = "CottoneraRegion"
	manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	status = String(manifest.status)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.72,.72,.72)
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = .95
	for record in manifest.regions:
		var region := Node3D.new()
		region.name = String(record.id).capitalize()
		var point := MaltaGeography.vector(record.position)
		region.position = Vector3(point.x,0,point.z)
		region.set_meta("source_status",record.status)
		region.set_meta("geonameid",record.geonameid)
		add_child(region)
		regions[record.id] = region
		for chunk in record.chunks:
			for level in ["mid","near","far"]:
				if chunk.has(level):_visual(region,String(chunk[level]),level,material)
			if chunk.has("collision"):_collision(region,String(chunk.collision))
		if record.chunks.is_empty() and show_missing_data_markers:
			var label := Label3D.new()
			label.text = String(record.name)+" — GEOGRAPHIC PLACEHOLDER"
			label.position = Vector3(0,point.y+40,0)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			region.add_child(label)

func _visual(parent: Node3D, path: String, level: String, material: Material) -> void:
	var source: PackedScene = load(path) as PackedScene
	if source == null:
		push_error("Cottonera source asset is missing: "+path)
		return
	var node := source.instantiate() as Node3D
	parent.add_child(node)
	_configure(node,level,material)

func _configure(node: Node, level: String, material: Material) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		mesh.material_override = material
		mesh.visibility_range_begin = 5000 if level == "far" else 0
		mesh.visibility_range_end = 16000 if level == "far" else (5000 if level == "mid" else 700)
		mesh.visibility_range_end_margin = 100
		mesh.lod_bias = .7
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if level == "mid" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual_count += 1
	for child in node.get_children():_configure(child,level,material)

func _collision(parent: Node3D, path: String) -> void:
	var source: PackedScene = load(path) as PackedScene
	if source == null:
		push_error("Cottonera collision asset is missing: "+path)
		return
	var node := source.instantiate() as Node3D
	_collect_collision(parent,node,Transform3D.IDENTITY)
	node.free()

func _collect_collision(parent: Node3D, node: Node3D, pose: Transform3D) -> void:
	var composed := pose * node.transform
	if node is MeshInstance3D:
		var body := StaticBody3D.new()
		body.name = "MappedCottoneraSolid_%d" % collision_count
		body.collision_layer = 1
		body.collision_mask = 0
		parent.add_child(body)
		body.transform = composed
		var shape := CollisionShape3D.new()
		shape.shape = node.mesh.create_trimesh_shape()
		body.add_child(shape)
		collision_count += 1
	for child in node.get_children():
		if child is Node3D:_collect_collision(parent,child,composed)
