class_name StElmoLocations
extends RefCounted
static func is_fort(id: String) -> bool: return id in ["st_elmo","st_elmo_1","st_elmo_2","st_elmo_3"]
static func data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/malta/valletta/st_elmo.json"))
static func position_for(id: String) -> Vector3:
	var index: int=0 if id=="st_elmo" else int(id.get_slice("_",2))
	var point: Array=data().spawn_positions[index]
	return Vector3(point[0],point[2]+1.05,point[1])
static func options() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for field in MaltaGeography.data().airfields:result.append({"id":field.id,"name":field.name})
	result.append({"id":"st_elmo","name":"Fort St Elmo — Bofors Battery"})
	for i in range(1,4):result.append({"id":"st_elmo_%d"%i,"name":"St Elmo — Bofors %d"%i})
	return result
