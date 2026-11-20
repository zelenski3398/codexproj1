class_name Bf109Model
extends SpitfireModel
## Original procedural airframes generated from metre-scale station geometry.

var friedrich: bool
var flap_hinges: Array[Node3D] = []
var ailerons: Array[Node3D] = []
var elevators: Array[Node3D] = []
var shutters: Array[Node3D] = []
var lower_shutters: Array[Node3D] = []
var slat_hinges: Array[Node3D] = []
var slat_origins: Array[Vector3] = []
var blades: Array[Node3D] = []
var wing_roots: Array[Node3D] = []
var tail: Node3D
var rudder: Node3D
var machine_gun_ports: Array[Marker3D] = []
var cannon_ports: Array[Marker3D] = []
var color_dark := MeshKit.material(Color("252825"))
var marking_white := MeshKit.material(Color("d6d7c9"))
var yellow := MeshKit.material(Color("dab041"))

func _ready() -> void:
	name = "FriedrichModel" if friedrich else "EmilModel"
	green = MeshKit.material(Color("646a63") if friedrich else Color("61674b"), 0.63)
	brown = MeshKit.material(Color("485350") if friedrich else Color("424c3b"), 0.66)
	underside = MeshKit.material(Color("a4b0ad") if friedrich else Color("a1b1ad"), 0.65)
	var nose := -3.72 if friedrich else -3.6
	var stations: Array[Vector4] = [Vector4(nose, 0.28, 0.34, 0), Vector4(-3.2, 0.48, 0.52, -0.03), Vector4(-2.0, 0.55, 0.64, -0.04), Vector4(-0.6, 0.53, 0.63, -0.08), Vector4(0.65, 0.48, 0.55, -0.08), Vector4(2.0, 0.34, 0.42, -0.03), Vector4(3.35, 0.19, 0.24, 0.04), Vector4(4.12 if friedrich else 4.0, 0.075, 0.12, 0.12)]
	_station_mesh(self, stations.slice(0, 5), "FuselageForward")
	tail = _pivot(self, "TailAssembly", Vector3.ZERO)
	_station_mesh(tail, stations.slice(4), "FuselageAft")
	MeshKit.sphere(self, Vector3(0.55, 0.35 if friedrich else 0.47, 0.81), Vector3(0, -0.58, -2.78), underside).name = "ChinOilCooler"
	MeshKit.sphere(self, Vector3(0.28, 0.31, 0.64 if friedrich else 0.42), Vector3(-0.51, 0.01, -1.62), green).name = "PortSuperchargerIntake"
	MeshKit.sphere(self, Vector3(0.26, 0.25, 0.055), Vector3(-0.54, 0.01, -1.90 if friedrich else -1.80), color_dark)
	_build_canopy()
	for side in [-1.0, 1.0]:
		for i in 6:
			var exhaust := MeshKit.box(self, Vector3(0.14, 0.10, 0.18), Vector3(side * 0.49, -0.13, -2.89 + i * 0.208), color_dark)
			exhaust.name = "Exhaust%d_%d" % [int(side), i]
		_cross(self, Vector3(side * 0.43, 0.12, 1.37), 0.63, side)
		_tactical_number(side)
		machine_gun_ports.append(_muzzle(self, "MG17" + _side(side), Vector3(side * 0.19, 0.35, -3.58)))
		_build_wing(side)
		_build_tail(side)
	for position in [Vector3(0, 0.93, 0.69), Vector3(0, 1.49, 1.07)]:
		MeshKit.sphere(self, Vector3(0.05, 0.08, 0.05), position, color_dark)
	MeshKit.rod(self, Vector3(0, 0.93, 0.69), Vector3(0, 1.49, 1.07), 0.022, green).name = "AerialMast"
	MeshKit.rod(self, Vector3(0, 1.49, 1.07), Vector3(0, 1.37, 3.75), 0.006, color_dark).name = "AerialWire"
	_build_propeller(nose)
	if friedrich:
		cannon_ports.append(_muzzle(self, "MG151_20Hub", Vector3(0, 0, -4.72)))
	gun_ports.assign(machine_gun_ports + cannon_ports)
	_build_gear()

func _side(side: float) -> String:
	return "Left" if side < 0 else "Right"

func _pivot(parent: Node3D, label: String, point: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = point
	parent.add_child(node)
	return node

func _muzzle(parent: Node3D, label: String, point: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = label
	marker.position = point
	parent.add_child(marker)
	var tube := MeshKit.cylinder(parent, 0.035 if "MG17" in label else 0.052, 0.17, point + Vector3.BACK * 0.085, color_dark)
	tube.rotation.x = PI * 0.5
	return marker

func _station_mesh(parent: Node3D, stations: Array, label: String) -> void:
	var mesh := ArrayMesh.new()
	for lower in [false, true]:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row in range(stations.size() - 1):
			for j in range(12 if lower else 0, 24 if lower else 12):
				var points: Array[Vector3] = []
				for pair in [Vector2i(row,j), Vector2i(row+1,j), Vector2i(row+1,j+1), Vector2i(row,j+1)]:
					var ring: Vector4 = stations[pair.x]
					var angle: float = TAU * pair.y / 24.0
					points.append(Vector3(cos(angle) * ring.y, sin(angle) * ring.z + ring.w, ring.x))
				for index in [0, 1, 2, 0, 2, 3]: tool.add_vertex(points[index])
		tool.generate_normals()
		tool.set_material(underside if lower else green)
		tool.commit(mesh)
	MeshKit.mesh(parent, mesh, null).name = label

func _panel(parent: Node3D, shape: PackedVector2Array, thickness: float, material: Material, label: String) -> MeshInstance3D:
	# Extrude a planform polygon vertically. Separate meshes can detach or hinge.
	var poly := shape
	if not Geometry2D.is_polygon_clockwise(poly):
		poly.reverse()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles := Geometry2D.triangulate_polygon(poly)
	for layer in [-1, 1]:
		for i in range(0, triangles.size(), 3):
			for j in (range(3) if layer > 0 else [2, 1, 0]):
				var p := poly[triangles[i + j]]
				tool.add_vertex(Vector3(p.x, layer * thickness * 0.5, p.y))
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i+1) % poly.size()]
		for p in [Vector3(a.x,-thickness/2,a.y), Vector3(a.x,thickness/2,a.y), Vector3(b.x,thickness/2,b.y), Vector3(a.x,-thickness/2,a.y), Vector3(b.x,thickness/2,b.y), Vector3(b.x,-thickness/2,b.y)]:
			tool.add_vertex(p)
	tool.generate_normals()
	var panel := MeshKit.mesh(parent, tool.commit(), material)
	panel.name = label
	return panel

func _build_wing(side: float) -> void:
	var suffix := _side(side)
	var wing := _pivot(self, suffix + "Wing", Vector3.ZERO)
	wing_roots.append(wing)
	var outline: Array[Vector2] = [Vector2(.36,-1.28), Vector2(2.45,-1.19), Vector2(4.23,-.97)]
	if friedrich:
		outline.append_array([Vector2(4.68,-.76), Vector2(4.96,-.44), Vector2(4.88,-.12), Vector2(4.56,.16)])
	else:
		outline.append_array([Vector2(4.90,-.83), Vector2(4.935,-.17), Vector2(4.68,.14)])
	outline.append_array([Vector2(2.37,.72), Vector2(.36,.89)])
	var plan := PackedVector2Array()
	for point in outline: plan.append(Vector2(side * point.x, point.y))
	var panel := _panel(wing, plan, .20, green, "WingSkin")
	panel.position.y = -0.17
	# Distinct angular camouflage patches, flush with the upper surface.
	var patch := PackedVector2Array([Vector2(side*.83,-1.1),Vector2(side*3.85,-1.0),Vector2(side*3.04,.43),Vector2(side*1.76,.71)])
	_panel(wing, patch, .025, brown, "Camouflage").position.y = -.060
	_cross(wing, Vector3(side*3.57,-.029,-.38), .91, 0)
	var flap := _pivot(wing, "LandingFlap" + suffix, Vector3(side * 1.37, -.17, .75))
	MeshKit.box(flap, Vector3(1.97,.10,.47), Vector3(0,0,.235), green).name = "FlapSkin"
	flap_hinges.append(flap)
	var aileron := _pivot(wing, "Aileron" + suffix, Vector3(side*3.64,-.17,.24))
	aileron.rotation.y = side * .21
	MeshKit.box(aileron, Vector3(2.04,.097,.32), Vector3(0,0,.14), green)
	ailerons.append(aileron)
	var slat := _pivot(wing, "AutomaticSlat" + suffix, Vector3(side*3.61,-.16,-1.02))
	slat.rotation.y = side * .11
	MeshKit.sphere(slat, Vector3(2.54,.16,.24), Vector3.ZERO, green)
	slat_hinges.append(slat)
	slat_origins.append(slat.position)
	var rad := Vector3(side*(1.57 if friedrich else 1.90), -.34, -.17)
	var housing := MeshKit.sphere(wing, Vector3(1.30 if friedrich else 1.13,.30 if friedrich else .46,1.18), rad, underside)
	housing.name = "CoolantBath" + suffix
	MeshKit.box(wing, Vector3(1.04,.11,.07), rad + Vector3(0,-.05,-.43), color_dark)
	var shutter := _pivot(wing, "RadiatorOutlet" + suffix, rad + Vector3(0,-.09,.38))
	MeshKit.box(shutter, Vector3(1.11,.065,.43), Vector3(0,0,.18), underside)
	shutters.append(shutter)
	if friedrich:
		var lower_shutter := _pivot(wing, "CoupledLowerShutter" + suffix, rad + Vector3(0,-.18,.31))
		MeshKit.box(lower_shutter, Vector3(1.11,.055,.41), Vector3(0,0,.18), underside)
		lower_shutters.append(lower_shutter)
	if not friedrich:
		cannon_ports.append(_muzzle(wing, "MGFF_M" + suffix, Vector3(side*2.17,-.18,-1.49)))

func _build_tail(side: float) -> void:
	var surface := _panel(tail, PackedVector2Array([Vector2(0,2.92),Vector2(side*1.55,3.18),Vector2(side*1.53,3.72),Vector2(0,3.73)]), .12, green, "Stabilizer" + _side(side))
	surface.position.y = .16
	var elevator := _pivot(tail, "Elevator" + _side(side), Vector3(side*.79,.16,3.72))
	MeshKit.box(elevator, Vector3(1.51,.09,.32), Vector3(0,0,.15), underside)
	elevators.append(elevator)
	if not friedrich:
		MeshKit.rod(tail, Vector3(side*.13,-.31,3.37), Vector3(side*1.11,.11,3.34), .039, underside).name = "StabilizerBrace" + _side(side)
	if side < 0:
		MeshKit.sphere(tail, Vector3(.19,1.46,1.09), Vector3(0,.69,3.49), green).name = "VerticalFin"
		rudder = _pivot(tail, "Rudder", Vector3(0,.72,3.79))
		MeshKit.sphere(rudder, Vector3(.15,1.45,.54), Vector3(0,0,.17), brown)

func _tactical_number(side: float) -> void:
	var number := Label3D.new()
	number.name = "TacticalNumber" + _side(side)
	number.text = "12" if friedrich else "4"
	number.font_size = 64
	number.pixel_size = 0.007
	number.outline_size = 2
	number.modulate = Color("e0b442") if friedrich else Color("dddcd0")
	number.rotation.y = side * PI * 0.5
	number.position = Vector3(side * 0.493, .19, .55)
	add_child(number)

func _build_canopy() -> void:
	var glass := MeshKit.material(Color(0.37,0.56,0.61,0.32), .19)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var canopy := _pivot(self, "FramedCanopy", Vector3(0,.46,.17))
	# Windshield slopes into the first rigid frame. The E has a squarer hood
	# and a broader flat front, while the F's glazing narrows into the cowling.
	var front_width := .29 if friedrich else .35
	var rear_width := .29 if friedrich else .34
	var front_bottom := [Vector3(-front_width,.02,-.69), Vector3(front_width,.02,-.69)]
	var front_top := [Vector3(-.28,.53,-.34), Vector3(.28,.53,-.34)]
	var back_bottom := [Vector3(-rear_width,.03,.60), Vector3(rear_width,.03,.60)]
	var back_top := [Vector3(-.27,.47,.39), Vector3(.27,.47,.39)]
	var planes := [
		[front_bottom[0], front_bottom[1], front_top[1], front_top[0]],
		[front_top[0], front_top[1], back_top[1], back_top[0]],
		[back_bottom[1], back_bottom[0], back_top[0], back_top[1]],
		[front_bottom[0], front_top[0], back_top[0], back_bottom[0]],
		[front_bottom[1], back_bottom[1], back_top[1], front_top[1]]
	]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for panel in planes:
		for i in [0,1,2,0,2,3]: tool.add_vertex(panel[i])
	tool.generate_normals()
	MeshKit.mesh(canopy, tool.commit(), glass).name = "Glazing"
	for i in 2:
		MeshKit.rod(canopy, front_bottom[i], front_top[i], .022, green)
		MeshKit.rod(canopy, front_top[i], back_top[i], .021, green)
		MeshKit.rod(canopy, back_top[i], back_bottom[i], .022, green)
		MeshKit.rod(canopy, front_bottom[i].lerp(back_bottom[i],.56), front_top[i].lerp(back_top[i],.56), .018, green)
	for frame in [front_top, back_top]:
		MeshKit.rod(canopy, frame[0], frame[1], .021, green)
	MeshKit.box(canopy, Vector3(.52,.39,.09), Vector3(0,.18,.39), brown).name = "HeadArmour"

func _build_propeller(nose: float) -> void:
	_build_spinner(nose)
	for i in 3:
		var blade := _pivot(propeller, "VDMBlade%d" % i, Vector3.ZERO)
		blade.rotation.z = TAU * i / 3
		var pitch_hinge := _pivot(blade, "Pitch", Vector3(0,.19,0))
		MeshKit.sphere(pitch_hinge, Vector3(.22,1.15,.065), Vector3(0,.59,0), color_dark)
		blades.append(pitch_hinge)

func _build_spinner(nose: float) -> void:
	MeshKit.sphere(self, Vector3(.58 if friedrich else .53, .56 if friedrich else .57, .42), Vector3(0,0,nose-.08), green).name = "PropellerReductionHousing"
	propeller = _pivot(self, "VDMPropeller", Vector3(0,0,nose-.30))
	var tip := MeshKit.sphere(propeller, Vector3(.72 if friedrich else .57,.73 if friedrich else .58,.99 if friedrich else .54), Vector3(0,0,-.20), brown if friedrich else yellow)
	tip.name = "RoundedSpinner" if friedrich else "ShortSpinner"

func _build_gear() -> void:
	for i in 3:
		var wheel := _pivot(self, "Tailwheel" if i == 2 else "MainWheel" + str(i), Vector3.ZERO)
		wheel_roots.append(wheel)
		var tyre := MeshKit.cylinder(wheel, .18 if i == 2 else .32, .13 if i == 2 else .20, Vector3.ZERO, rubber)
		tyre.rotation.z = PI * .5
		var hub := MeshKit.cylinder(wheel, .085 if i == 2 else .16, .145 if i == 2 else .21, Vector3.ZERO, metal)
		hub.rotation.z = PI * .5
		var strut := MeshKit.cylinder(self, .052, .5, Vector3.ZERO, metal)
		struts.append(strut)
		if i < 2:
			MeshKit.box(strut, Vector3(.20,.44,.055), Vector3(.069,0,0), underside).name = "MainGearDoor"

func _cross(parent: Node3D, pos: Vector3, size: float, side: float) -> void:
	# Period-style national wing and fuselage crosses. Original generic livery.
	var cross := _pivot(parent, "NationalCross", pos)
	if side != 0: cross.rotation.z = side * PI * 0.5
	for dimensions in [Vector3(size,.012,size*.27),Vector3(size*.27,.012,size)]:
		MeshKit.box(cross, dimensions, Vector3.ZERO, marking_white)
		MeshKit.box(cross, dimensions * Vector3(.76,1,.76), Vector3.UP*.009, color_dark)

func animate(delta: float, throttle: float, gear: LandingGear, broken: bool) -> void:
	var plane := get_parent() as Bf109
	if not broken and (plane == null or plane.engine_running):
		propeller.rotation.z += delta * lerpf(20,105,throttle) * float(engine_factors.get(0,1))
	for blade in blades:
		blade.rotation.y = lerpf(.20,.56,clampf((plane.airspeed if plane != null else 0.0) / 115.0,0,1))
	_animate_retractable_gear(delta, gear, Vector3(.62,-.13,-1.06), 1.98, gear.anchors[2])
	for i in 2:
		wheel_roots[i].rotation.z = (-1.0 if i == 0 else 1.0) * (1.0 - gear_mix) * 1.48
	if friedrich:
		var tailwheel := wheel_roots[2]
		var deployed := tailwheel.position
		tailwheel.position = Vector3(0,-.28,deployed.z).lerp(deployed,gear_mix)
		tailwheel.visible = true
		struts[2].visible = gear_mix > .28
		struts[2].position = (tailwheel.position + gear.anchors[2]) * .5
		struts[2].scale.y = maxf(tailwheel.position.distance_to(gear.anchors[2]),.01)/.5
	if plane == null or broken: return
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		wing_roots[i].visible = not plane.components.detached.has(&"left_wing" if side < 0 else &"right_wing")
		ailerons[i].rotation.x = side * plane.pilot.roll * .37 * plane.components.roll_factor(plane.pilot.roll) + plane.devices.flaps * .12
		elevators[i].rotation.x = plane.pilot.pitch * .33 * plane.components.elevator_factor()
		slat_hinges[i].position = slat_origins[i] + Vector3(0,-.045,-.18) * plane.slats[i]
		shutters[i].rotation.x = plane.radiator * (.27 if friedrich else .46)
		if friedrich: lower_shutters[i].rotation.x = plane.devices.flaps * .53
	tail.visible = not plane.components.detached.has(&"tail")
	rudder.rotation.y = plane.pilot.rudder * .38 * plane.components.rudder_factor()
