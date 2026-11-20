class_name Bf109
extends FlightAircraft

const EMIL := "bf109_e4"
const FRIEDRICH := "bf109_f4"
const KINDS: Array[String] = [EMIL, FRIEDRICH]
var variant: String = EMIL
var cannon: WingGuns
var slats: Vector2
var slat_demand: Array[bool] = [false, false]
var radiator: float = 0.65
var manual_radiator: float = 0.65
var coolant: float = 0.5

static func title(kind: String) -> String:
	return "Bf 109 F-4 Friedrich" if kind == FRIEDRICH else "Bf 109 E-4 Emil"

func create_model() -> SpitfireModel:
	var visual := Bf109Model.new()
	visual.friedrich = variant == FRIEDRICH
	return visual

func create_flight_devices() -> FlightDevices:
	return Bf109Devices.new()

func default_damage_profile() -> AircraftDamageProfile:
	return preload("res://damage_profiles/bf109.tres")

func _ready() -> void:
	var f := variant == FRIEDRICH
	display_name = title(variant)
	gun_description = "2 × MG 17 + MG 151/20 hub cannon" if f else "2 × MG 17 + 2 × MG FF/M wing cannon"
	collision_wing_span = 9.92 if f else 9.87
	wing_area = 16.05 if f else 16.2
	engine_thrust = 15100 if f else 12900
	lift_at_zero_alpha = 0.56 if f else 0.62
	lift_slope = 4.8 if f else 4.55
	parasite_drag = 0.028 if f else 0.037
	stall_angle_degrees = 15 if f else 16
	stall_speed = 31 if f else 29
	roll_torque = 22800 if f else 20700
	pitch_torque = 18300 if f else 17600
	rudder_torque = 11900 if f else 11200
	flap_landing_degrees = 40 if f else 42
	flap_operating_speed = 69.4 if f else 66.7
	flap_deploy_seconds = 7.0 if f else 8.0
	flap_pitch_moment = -1300 if f else -1650
	flap_lift_coefficient = 0.40 if f else 0.46
	flap_drag_coefficient = 0.12 if f else 0.14
	takeoff_speed_hint = "150–170"
	approach_speed_hint = "145–165"
	safe_speed_hint = 135
	super._ready()
	mass = 2890 if f else 2600
	inertia = Vector3(7200, 10100, 5800) if f else Vector3(6800, 9700, 5500)
	gear.anchors.assign([Vector3(-0.96, -0.60, -1.06), Vector3(0.96, -0.60, -1.06), Vector3(0, -0.30, 3.53)])
	gear.fixed_tailwheel = not f
	gear.travel.assign([0.45, 0.45, 0.30])
	gear_drag_coefficient = 0.036 if f else 0.041
	seated_pilot.position = Vector3(0, -0.75, 0.23)
	var visual := model as Bf109Model
	cannon = WingGuns.new()
	cannon.name = "Cannon"
	cannon.aircraft = self
	cannon.firing_ports.assign(visual.cannon_ports)
	cannon.rounds_per_port = 200 if f else 60
	cannon.bullet_speed = 705 if f else 585
	cannon.bullet_damage = 8.5 if f else 7.5
	cannon.rounds_per_second = 12.0 if f else 8.7
	cannon.spread_degrees = 0.13
	cannon.firing_sound = preload("res://assets/audio/aa_cannon_shot.ogg")
	add_child(cannon)
	reset_completed.connect(_reset_mechanisms)

func configure_gun_battery(battery: WingGuns) -> void:
	battery.name = "CowlingMG17"
	battery.firing_ports.assign((model as Bf109Model).machine_gun_ports)
	battery.rounds_per_port = 500 if variant == FRIEDRICH else 1000
	battery.bullet_speed = 755
	battery.bullet_damage = 2.1
	battery.rounds_per_second = 15.7
	battery.spread_degrees = 0.11

func _reset_mechanisms() -> void:
	slats = Vector2.ZERO
	slat_demand.assign([false, false])
	radiator = 0.65
	manual_radiator = 0.65
	coolant = 0.5

func clear_secondary_weapons(restore: bool) -> void:
	if is_instance_valid(cannon): cannon.reset(restore)

func advance_airframe(dt: float, local_velocity: Vector3, local_spin: Vector3) -> void:
	var f := variant == FRIEDRICH
	for i in 2:
		var offset := Vector3(-3.2 if i == 0 else 3.2, 0, -0.6)
		var flow := local_velocity + local_spin.cross(offset)
		var alpha := rad_to_deg(atan2(-flow.y, maxf(-flow.z, 0.1)))
		var threshold := (11.0 if f else 12.0) - (2.0 if slat_demand[i] else 0.0)
		slat_demand[i] = -flow.z > 18 and alpha > threshold and not components.detached.has(&"left_wing" if i == 0 else &"right_wing")
		slats[i] = move_toward(slats[i], 1.0 if slat_demand[i] else 0.0, dt * 3)
	var mean := (slats.x + slats.y) * 0.5
	slat_stall_bonus = deg_to_rad(4.0) * mean
	slat_lift_bonus = 0.20 * mean
	slat_roll_moment = 420 * (slats.y - slats.x)
	var airflow := clampf(-local_velocity.z / 90.0, 0, 1)
	var heating := pilot.throttle * 0.038 if engine_running and not is_destroyed else 0.0
	coolant = clampf(coolant + dt * (heating - (0.012 + airflow * 0.038) * radiator - 0.008), 0, 1)
	if input_enabled and not f:
		manual_radiator = clampf(manual_radiator + Input.get_axis("radiator_close", "radiator_open") * dt * 0.45, 0.15, 1)
	var demand := clampf(0.33 + (coolant - 0.46) * 2.2, 0.15, 1) if f else manual_radiator
	radiator = move_toward(radiator, demand, dt * 0.65)
	cooling_drag = radiator * (0.008 if f else 0.014)
	if coolant > 0.95 and engine_running and not is_destroyed:
		devices.message("COOLANT HOT · reduce power" if f else "COOLANT HOT · L opens radiator")
