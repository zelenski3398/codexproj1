class_name MdinaCity
extends HistoricCity
## Original georeferenced Mdina: static architecture, no mission ownership.
const LAYOUT_PATH: String = "res://assets/malta/mdina/layout.json"
func _init() -> void:
	city_name = "MdinaCity"
	layout_path = LAYOUT_PATH
	visual_scene = preload("res://assets/malta/mdina/city.glb")
	collision_scene = preload("res://assets/malta/mdina/collision.glb")
	detail_distance = 1400
