class_name MaltaGeography
extends RefCounted
## One chart transform for selection, navigation, markers and tests. North is -Z.
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/malta/world_data.json"))
	return _data

static func vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

static func chart_uv(position: Vector3) -> Vector2:
	var bounds: Array = data().chart_bounds
	return Vector2((position.x - float(bounds[0])) / (float(bounds[2]) - float(bounds[0])), (position.z - float(bounds[1])) / (float(bounds[3]) - float(bounds[1])))

static func chart_to_world(uv: Vector2, height: float = 0) -> Vector3:
	var bounds: Array = data().chart_bounds
	return Vector3(lerpf(float(bounds[0]), float(bounds[2]), uv.x), height, lerpf(float(bounds[1]), float(bounds[3]), uv.y))

static func field(id: String) -> Dictionary:
	for record in data().airfields:
		if record.id == id:
			return record
	return {}
