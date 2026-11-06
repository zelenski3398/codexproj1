class_name FlightDevices
extends Node
## Commands and animated ratios only; FlightAircraft applies all aerodynamic forces.
var aircraft: FlightAircraft
var flap_target: bool = false
var brake_target: bool = false
var flaps: float = 0
var airbrakes: float = 0
var notice: String = ""
var notice_time: float = 0
var surfaces: Array[Node3D] = []
var brake_surfaces: Array[Node3D] = []

func _ready() -> void:
	for side in [-1.0, 1.0]:
		if aircraft.flaps_available:
			var hinge := Node3D.new()
			hinge.name = "LandingFlapLeft" if side < 0 else "LandingFlapRight"
			hinge.position = Vector3(side * aircraft.collision_wing_span * .22, -.16, .48)
			if aircraft.model is StukaModel:
				hinge.position.y = -.30
				hinge.position.z = 1.12
				hinge.rotation.z = side * .15
			elif aircraft.model is HurricaneModel:
				hinge.position.y = -.03
				hinge.position.z = .80
			aircraft.model.add_child(hinge)
			MeshKit.box(hinge, Vector3(aircraft.collision_wing_span * .20, .055, .42), Vector3(0, 0, .21), aircraft.model.underside)
			surfaces.append(hinge)
		if aircraft.airbrakes_available or aircraft.gameplay_airbrake_assist:
			var hinge := Node3D.new()
			hinge.name = "DiveBrakeLeft" if side < 0 else "DiveBrakeRight"
			hinge.position = Vector3(side * aircraft.collision_wing_span * .28, -.28, -.7)
			aircraft.model.add_child(hinge)
			# Open slatted dive-brake panel, not a solid floating rectangle.
			for i in 5:
				MeshKit.box(hinge, Vector3(.95, .035, .045), Vector3(0, 0, i * .09), aircraft.model.metal)
			for x in [-.40, .40]:
				MeshKit.box(hinge, Vector3(.035, .04, .42), Vector3(x, 0, .18), aircraft.model.metal)
			brake_surfaces.append(hinge)

func command_flaps(deploy: bool) -> bool:
	if aircraft.is_destroyed or aircraft.is_crashed: return false
	if not aircraft.flaps_available:
		message("FLAPS UNAVAILABLE")
		return false
	if deploy and aircraft.airspeed > aircraft.flap_operating_speed:
		message("FLAPS OVERSPEED")
		return false
	flap_target = deploy
	return true

func command_airbrakes(deploy: bool) -> bool:
	if aircraft.is_destroyed or aircraft.is_crashed: return false
	if not aircraft.airbrakes_available and not aircraft.gameplay_airbrake_assist:
		message("AIRBRAKES UNAVAILABLE")
		return false
	brake_target = deploy
	return true

func message(text: String) -> void:
	notice = text
	notice_time = 3

func advance(dt: float) -> void:
	if aircraft.pilot.automated and aircraft is EnemyAircraft and not aircraft.is_destroyed and not aircraft.is_crashed:
		var enemy := aircraft as EnemyAircraft
		var diving: bool = enemy.ai is DiveAttackPilot and (enemy.ai as DiveAttackPilot).attack_state == "DIVE"
		# Devices use the same commands/forces. Normal combat always retracts;
		# slow, low emergency approaches may use landing flaps.
		var landing: bool = not diving and enemy.ai.damage_emergency != "" and aircraft.altitude < 40 and aircraft.airspeed < aircraft.flap_operating_speed and aircraft.gear.extended
		if flap_target != landing and aircraft.flaps_available: command_flaps(landing)
		var use_brakes: bool = diving and aircraft.airspeed > (aircraft.ai_dive_brake_retract_speed if brake_target else aircraft.ai_dive_brake_deploy_speed)
		if brake_target != use_brakes and aircraft.airbrakes_available: command_airbrakes(use_brakes)
	notice_time = maxf(0, notice_time - dt)
	if notice_time == 0: notice = ""
	# Leave wreck surfaces in their last physical position.
	if not aircraft.is_destroyed and not aircraft.is_crashed:
		flaps = move_toward(flaps, 1.0 if flap_target else 0.0, dt / maxf(.05, aircraft.flap_deploy_seconds))
		airbrakes = move_toward(airbrakes, 1.0 if brake_target else 0.0, dt / maxf(.05, aircraft.airbrake_deploy_seconds))
	sync_visuals()

func sync_visuals() -> void:
	for i in surfaces.size():
		surfaces[i].rotation.x = deg_to_rad(lerpf(aircraft.flap_retracted_degrees, aircraft.flap_landing_degrees, flaps))
		surfaces[i].visible = not aircraft.components.detached.has(&"left_wing" if i == 0 else &"right_wing")
	for i in brake_surfaces.size():
		brake_surfaces[i].rotation.x = deg_to_rad(80 * airbrakes)
		brake_surfaces[i].visible = not aircraft.components.detached.has(&"left_wing" if i == 0 else &"right_wing")

func reset() -> void:
	flap_target = false; brake_target = false
	flaps = 0; airbrakes = 0; notice = ""; notice_time = 0
	sync_visuals()

func status() -> String:
	return "Flaps %s · Airbrake %s%s" % [str(roundi(flaps * 100)) + "%" if aircraft.flaps_available else "N/A", str(roundi(airbrakes * 100)) + "%" if aircraft.airbrakes_available or aircraft.gameplay_airbrake_assist else "N/A", " (assist)" if aircraft.gameplay_airbrake_assist and not aircraft.airbrakes_available else ""]
