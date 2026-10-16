class_name VallettaCity
extends HistoricCity
## Existing Valletta asset/settings, using the shared static city renderer.
const LAYOUT_PATH: String = "res://assets/malta/valletta/layout.json"
func _init() -> void:
	city_name = "VallettaCity"
	layout_path = LAYOUT_PATH
	visual_scene = preload("res://assets/malta/valletta/city.glb")
	collision_scene = preload("res://assets/malta/valletta/collision.glb")
