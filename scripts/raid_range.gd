class_name RaidRange
extends Node3D
## Fictional destructible additions within the existing Malta scene.

const TARGET_WEST: StringName = &"st_elmo_store_roof_west"
const TARGET_EAST: StringName = &"st_elmo_store_roof_east"
const TARGET_IDS: Array[StringName] = [TARGET_WEST, TARGET_EAST]
const FORT_OFFSET := Vector3(13, 0, -12)
var sections: Dictionary = {}
var target_position: Vector3
var target_marker: Label3D

static func fort_anchor() -> Vector3:
	return StElmoLocations.position_for("st_elmo") + FORT_OFFSET

func build(show_marker: bool) -> void:
	# The imported fort and terrain bodies enter the broad phase after startup.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree(): return
	target_position = fort_anchor()
	var support := _surface(target_position)
	if not support.is_empty(): target_position.y = support.position.y
	_building("st_elmo_store", target_position, 12, 10)
	_section("st_elmo_parapet_north", target_position + Vector3(0, 0.85, -9), Vector3(12, 1.7, 1))
	_section("st_elmo_parapet_south", target_position + Vector3(0, 0.85, 9), Vector3(12, 1.7, 1))
	for i in range(3):
		var anchor := target_position + Vector3(-29 - i * 19, 0, 30 + i * 13)
		var ground := _surface(anchor)
		if not ground.is_empty() and ground.normal.y > 0.8 and not ground.collider.is_in_group("aircraft_water"):
			_building("raid_annex_%d" % i, ground.position, 9, 8)
	if show_marker:
		target_marker = Label3D.new()
		target_marker.text = "◆  ST ELMO TARGET"
		target_marker.modulate = Color("ffcb63")
		target_marker.font_size = 38
		target_marker.pixel_size = 0.22
		target_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		target_marker.no_depth_test = true
		add_child(target_marker)
		target_marker.global_position = target_position + Vector3.UP * 12

func _surface(anchor: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(anchor + Vector3.UP * 75, anchor + Vector3.DOWN * 60, 1)
	return get_world_3d().direct_space_state.intersect_ray(query)

func _building(id: String, base: Vector3, width: float, depth: float) -> void:
	for edge in [-1.0, 1.0]:
		var side := "west" if edge < 0 else "east"
		var end := "north" if edge < 0 else "south"
		_section(id + "_wall_" + side, base + Vector3(edge * (width * 0.5 - 0.35), 1.6, 0), Vector3(0.7, 3.2, depth))
		_section(id + "_wall_" + end, base + Vector3(0, 1.6, edge * (depth * 0.5 - 0.35)), Vector3(width - 1.4, 3.2, 0.7))
		_section(id + "_roof_" + side, base + Vector3(edge * width * 0.25, 3.5, 0), Vector3(width * 0.5, 0.6, depth))

func _section(id: String, point: Vector3, dimensions: Vector3) -> void:
	var section := BombStructureSection.new()
	section.section_id = StringName(id)
	section.name = id
	section.size = dimensions
	section.position = to_local(point)
	add_child(section)
	sections[section.section_id] = section
