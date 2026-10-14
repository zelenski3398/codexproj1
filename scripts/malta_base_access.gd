class_name MaltaBaseAccess
extends RefCounted
## Editable local navigation/paint data. No runtime GIS or road reconstruction.
static var cached: Dictionary={}
static func data() -> Dictionary:
	if cached.is_empty():cached=JSON.parse_string(FileAccess.get_file_as_string("res://assets/malta/roads/base_access.json"))
	return cached
static func field(id: String) -> Dictionary:return data().bases.get(id,{})
static func paint(material: ShaderMaterial,record: Dictionary) -> void:
	var access: Dictionary=field(String(record.id))
	var starts:=PackedVector2Array()
	var ends:=PackedVector2Array()
	for lane in access.lanes:
		starts.append(Vector2(lane.from[0],lane.from[1]))
		ends.append(Vector2(lane.to[0],lane.to[1]))
	while starts.size()<8:starts.append(Vector2.ZERO);ends.append(Vector2.ZERO)
	material.set_shader_parameter("access_count",access.lanes.size())
	material.set_shader_parameter("access_start",starts)
	material.set_shader_parameter("access_end",ends)
	material.set_shader_parameter("access_origin",Vector2(61,float(record.length)*.31))
	material.set_shader_parameter("access_half_width",float(access.width)*.5)
