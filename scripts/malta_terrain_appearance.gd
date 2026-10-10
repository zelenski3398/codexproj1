class_name MaltaTerrainAppearance
extends Node
signal debug_mode_changed(enabled: bool)
## Rendering only. Preserve imported geometry, vertex colours, LODs, collision
## and transforms; never depend on importer-generated surface materials.
const LIMESTONE: StandardMaterial3D = preload("res://assets/malta/materials/limestone.tres")
const LANDSCAPE: ShaderMaterial = preload("res://assets/malta/materials/landscape.tres")
const HEATMAP: StandardMaterial3D = preload("res://assets/malta/materials/elevation_heatmap.tres")
@export var debug_heatmap_enabled: bool = false
var meshes: Array[MeshInstance3D] = []
var debug_notice: Label

func _ready() -> void:
	# Only this render/debug component runs while paused, not world physics.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 90
	add_child(canvas)
	debug_notice = Label.new()
	debug_notice.text = "DEBUG: ELEVATION HEATMAP | F4 returns to landscape"
	debug_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_notice.add_theme_font_size_override("font_size", 18)
	debug_notice.add_theme_color_override("font_color", Color("ffe09a"))
	debug_notice.add_theme_color_override("font_shadow_color", Color.BLACK)
	debug_notice.add_theme_constant_override("shadow_offset_x", 2)
	debug_notice.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(debug_notice)
	debug_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	debug_notice.offset_left = -350
	debug_notice.offset_right = 350
	debug_notice.offset_top = 200
	debug_notice.offset_bottom = 228
	set_debug_heatmap(debug_heatmap_enabled)

func register_mesh(mesh: MeshInstance3D) -> void:
	meshes.append(mesh)
	mesh.material_override = HEATMAP if debug_heatmap_enabled else LANDSCAPE

func set_debug_heatmap(enabled: bool) -> void:
	debug_heatmap_enabled = enabled
	var material: Material = HEATMAP if enabled else LANDSCAPE
	for mesh in meshes:
		mesh.material_override = material
	if is_instance_valid(debug_notice):
		debug_notice.visible = enabled
	debug_mode_changed.emit(enabled)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_terrain_heatmap") and not event.is_echo():
		set_debug_heatmap(not debug_heatmap_enabled)
		get_viewport().set_input_as_handled()

func diagnostic_state() -> Dictionary:
	var expected: Material = HEATMAP if debug_heatmap_enabled else LANDSCAPE
	var matching: int = 0
	for mesh in meshes:
		if mesh.material_override == expected:
			matching += 1
	var textures: Array[String] = []
	if not debug_heatmap_enabled:
		for parameter in ["landcover", "surface_detail", "cliff_detail"]:
			var texture: Texture2D = LANDSCAPE.get_shader_parameter(parameter)
			textures.append(texture.resource_path if texture != null else "MISSING")
	return {"heatmap": debug_heatmap_enabled, "material": expected.resource_path, "vertex_colors_as_albedo": debug_heatmap_enabled, "mesh_count": meshes.size(), "matching_meshes": matching, "texture_free": textures.is_empty(), "textures": textures, "debug_label_visible": debug_notice.visible}
