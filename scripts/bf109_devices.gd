class_name Bf109Devices
extends FlightDevices

func uses_progressive_flaps() -> bool:
	return true

func _ready() -> void:
	surfaces.assign((aircraft.model as Bf109Model).flap_hinges)

func advance(dt: float) -> void:
	notice_time = maxf(0, notice_time - dt)
	if notice_time == 0: notice = ""
	if remote_commands:
		super.advance(dt)
		return
	if not aircraft.input_enabled or aircraft.is_destroyed or aircraft.is_crashed or aircraft.pilot.automated:
		return
	if not Input.is_action_pressed("flaps"): return
	var retract := Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_SHIFT)
	if not retract and aircraft.airspeed > aircraft.flap_operating_speed:
		message("FLAPS OVERSPEED")
		return
	flaps = move_toward(flaps, 0.0 if retract else 1.0, dt / aircraft.flap_deploy_seconds)
	sync_visuals()
