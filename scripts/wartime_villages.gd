class_name WartimeVillages
extends Node3D

const LAYOUT := "res://assets/malta/villages/layout.json"
const SURFACE := preload("res://assets/malta/villages/surface.png")
static var _layout: Dictionary
static var _areas: Array[Dictionary] = []
static var _grid: Dictionary = {}
var terrain_root: Node3D
var districts: Dictionary = {}
var _build_index := -2


static func layout() -> Dictionary:
	if _layout.is_empty():
		_layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
		for site in _layout.sites:
			for polygon in site.polygons:
				var shell := MostaVillage._polygon(polygon.shell)
				var bounds := Rect2(shell[0], Vector2.ZERO)
				for point in shell:
					bounds = bounds.expand(point)
				var holes: Array[PackedVector2Array] = []
				for hole in polygon.holes:
					holes.append(MostaVillage._polygon(hole))
				var index := _areas.size()
				_areas.append({"bounds": bounds, "shell": shell, "holes": holes})
				for x in range(floori(bounds.position.x / 256), floori(bounds.end.x / 256) + 1):
					for z in range(floori(bounds.position.y / 256), floori(bounds.end.y / 256) + 1):
						var key := Vector2i(x, z)
						if not _grid.has(key):
							_grid[key] = []
						_grid[key].append(index)
	return _layout


static func apply_mask(material: ShaderMaterial) -> void:
	var data: Array = layout().mask
	material.set_shader_parameter("village_surface_mask", SURFACE)
	material.set_shader_parameter("village_surface_min", Vector2(data[0], data[1]))
	material.set_shader_parameter("village_surface_span", float(data[2]))


static func replaces_scenery(point: Vector3) -> bool:
	var xz := Vector2(point.x, point.z)
	var key := Vector2i(floori(xz.x / 256), floori(xz.y / 256))
	for index in _grid.get(key, []):
		var area := _areas[int(index)]
		if not area.bounds.has_point(xz) or not Geometry2D.is_point_in_polygon(xz, area.shell):
			continue
		if not area.holes.any(func(hole): return Geometry2D.is_point_in_polygon(xz, hole)):
			return true
	return false


static func intersects_area(box: AABB) -> bool:
	var xz := Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
	return _areas.any(func(area): return area.bounds.intersects(xz))


static func recovery_street_points() -> PackedVector2Array:
	var result := PackedVector2Array()
	for site in layout().sites:
		for street in site.streets:
			var points := MostaVillage._polygon(street.points)
			for i in range(points.size() - 1):
				var count := maxi(1, ceili(points[i].distance_to(points[i + 1]) / 4.0))
				for step in count:
					result.append(points[i].lerp(points[i + 1], float(step) / count))
	return result


func _ready() -> void:
	name = "WartimeVillages"


func _physics_process(_delta: float) -> void:
	# Leave two ticks for terrain colliders to enter the physics space.
	if _build_index < 0:
		_build_index += 1
		return
	var sites: Array = layout().sites
	var record: Dictionary = sites[_build_index]
	var district := WartimeDistrict.new()
	district.record = record
	district.terrain_root = terrain_root
	districts[record.id] = district
	add_child(district)
	_build_index += 1
	if _build_index == sites.size():
		set_physics_process(false)
