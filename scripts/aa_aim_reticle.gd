class_name AAAimReticle
extends Control
var gun: BritishAAGun
var marker_visible: bool = false
var aligned: bool = false
var last_marker: Vector2
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(_delta: float) -> void:
	if visible:queue_redraw()
func _draw() -> void:
	marker_visible=false;aligned=false
	var center := size*.5
	var color := Color("e4bf75")
	draw_arc(center,9,0,TAU,32,color,1.5)
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		draw_line(center+direction*13,center+direction*23,color,1.5)
	draw_circle(center,1.5,color)
	if not is_instance_valid(gun) or gun.weapon.heavy or AAMouseControls.fire_control_mode==0:return
	var font: Font=ThemeDB.fallback_font
	var solution: Dictionary=gun.aim_assist.solution
	if not is_instance_valid(gun.aim_assist.target):solution={}
	var notice: String="NO PREDICTOR ASSIGNMENT · F at an observation post to acquire and assign"
	if not solution.is_empty():
		var yaw_error: float=rad_to_deg(wrapf(solution.yaw-gun.yaw.rotation.y,-PI,PI))
		var pitch_error: float=rad_to_deg(solution.pitch-gun.elevation.rotation.x)
		aligned=solution.valid and solution.quality>.6 and (-gun.muzzle.global_basis.z).angle_to(solution.direction)<deg_to_rad(gun.weapon.predictor_alignment_degrees)
		notice="OUTSIDE FIRING ENVELOPE" if not solution.valid else ("ON TARGET" if aligned else ("Traverse %s %.1f° · %s %.1f°"%["left" if yaw_error>0 else "right",absf(yaw_error),"Elevate" if pitch_error>0 else "Depress",absf(pitch_error)]))
		notice+=" · Est range %d m · %s"%[roundi(solution.range_metres),"PREDICTOR READY" if solution.quality>.6 else "TRACK SETTLING"]
		if solution.valid and not gun.camera.is_position_behind(solution.aim_point):
			last_marker=gun.camera.unproject_position(solution.aim_point)
			if get_rect().has_point(last_marker):
				marker_visible=true
				var radius: float=14 if AAMouseControls.fire_control_mode==2 else 9
				var ink:=Color("62eed5") if solution.quality>.6 else Color("f0b259")
				var diamond:=PackedVector2Array([last_marker+Vector2(0,-radius),last_marker+Vector2(radius,0),last_marker+Vector2(0,radius),last_marker+Vector2(-radius,0),last_marker+Vector2(0,-radius)])
				draw_polyline(diamond,ink,2)
				draw_line(center,last_marker,Color(ink,.4),1)
				draw_string(font,last_marker+Vector2(radius+5,0),"AIM",HORIZONTAL_ALIGNMENT_LEFT,-1,16,ink)
		if AAMouseControls.fire_control_mode==2:
			draw_string(font,Vector2(30,size.y*.54+32),"TRAINING: put the gold reticle on the cyan diamond; lead includes shell travel time and gravity.",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("62eed5"))
			draw_string(font,Vector2(30,size.y*.54+54),"Keep tracking during the burst. Tracers show actual shell paths; sharp turns reduce prediction confidence.",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("62eed5"))
	draw_string(font,Vector2(30,size.y*.54),notice,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("eee8c6"))
