class_name AAAimReticle
extends Control
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _draw() -> void:
	var center := size*.5
	var color := Color("e4bf75")
	draw_arc(center,9,0,TAU,32,color,1.5)
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		draw_line(center+direction*13,center+direction*23,color,1.5)
	draw_circle(center,1.5,color)
