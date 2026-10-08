class_name FlightAircraft
extends RigidBody3D
signal crashed(reason: String)
signal reset_completed
signal destroyed

@export_group("Aerodynamics")
@export var wing_area: float = 22.5
@export var air_density: float = 1.225
@export var engine_thrust: float = 12500.0
@export var lift_at_zero_alpha: float = 0.62
@export var lift_slope: float = 4.6
@export var stall_angle_degrees: float = 16.0
@export var stall_speed: float = 32.0
@export var parasite_drag: float = 0.034
@export var induced_drag: float = 0.055
@export_group("Handling")
@export var pitch_torque: float = 19000.0
@export var roll_torque: float = 23000.0
@export var rudder_torque: float = 12500.0
@export var coordinated_turn: float = 1.4
@export var angular_response: float = 3.5
@export var reset_position: Vector3 = Vector3(0.0, 1.18, 650.0)

var pilot: PilotInput
var gear: LandingGear
var model: SpitfireModel
var health: AircraftHealth
var guns: WingGuns
var damage_effects: DamageEffects
var is_destroyed: bool = false
var airspeed: float = 0.0
var altitude: float = 0.0
var angle_of_attack: float = 0.0
var stalled: bool = false
var is_crashed: bool = false
var crash_reason: String = ""
var reset_pending: bool = false
## Pending state is applied inside the physics callback. Tests may supply an
## alternate reset pose/velocity to initialize a scenario, never during flight.
var pending_reset_pose: Transform3D
var pending_reset_velocity: Vector3 = Vector3.ZERO
var airborne_time: float = 0.0

func _ready() -> void:
	mass = 3000.0
	inertia = Vector3(9500.0, 14000.0, 8000.0)
	linear_damp = 0.0
	angular_damp = 0.0
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	can_sleep = false
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 8
	collision_layer = 2
	collision_mask = 1
	pilot = PilotInput.new()
	pilot.name = "PilotInput"
	add_child(pilot)
	gear = LandingGear.new()
	gear.name = "LandingGear"
	add_child(gear)
	model = SpitfireModel.new()
	add_child(model)
	health = AircraftHealth.new()
	health.name = "Health"
	add_child(health)
	damage_effects = DamageEffects.new()
	damage_effects.aircraft = self
	damage_effects.name = "EngineDamageEffects"
	add_child(damage_effects)
	health.changed.connect(damage_effects.set_health)
	health.depleted.connect(_destroy)
	guns = WingGuns.new()
	guns.aircraft = self
	guns.name = "EightWingGuns"
	add_child(guns)
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.46
	shape.height = 7.5
	collider.shape = shape
	collider.rotation.x = PI / 2.0
	collider.position.z = 0.25
	add_child(collider)
	var wings := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(9.8, 0.12, 1.3)
	wings.shape = box
	wings.position = Vector3(0.0, -0.12, -0.25)
	add_child(wings)
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.55
	physics_material_override.bounce = 0.0
	global_transform = Transform3D(Basis(Vector3.RIGHT, 0.117), reset_position)

func _input(event: InputEvent) -> void:
	# HUD owns reset/pause. Discrete commands ignore OS key-repeat.
	if event.is_action_pressed("gear") and not event.is_echo() and not is_crashed and not is_destroyed:
		gear.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_damage") and not event.is_echo():
		# Temporary development key; one hit per press, never OS repeat.
		take_damage(10.0)
		get_viewport().set_input_as_handled()

func take_damage(amount: float) -> void:
	health.take_damage(amount)

func _destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	pilot.reset_commands()
	guns.reset()
	destroyed.emit()

func request_reset() -> void:
	pending_reset_pose = Transform3D(Basis(Vector3.RIGHT, 0.117), reset_position)
	pending_reset_velocity = Vector3.ZERO
	reset_pending = true
	pilot.reset_commands()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if reset_pending:
		state.transform = pending_reset_pose
		state.linear_velocity = pending_reset_velocity
		state.angular_velocity = Vector3.ZERO
		gear.extended = true
		gear.contact_count = 0
		gear.last_notice = ""
		is_crashed = false
		is_destroyed = false
		health.reset()
		guns.reset()
		damage_effects.clear()
		crash_reason = ""
		stalled = false
		airborne_time = 0.0
		reset_pending = false
		reset_completed.emit()
		return
	var dt := state.step
	pilot.sample(dt)
	if is_destroyed:
		pilot.reset_commands()
	var basis := state.transform.basis.orthonormalized()
	var velocity := state.linear_velocity
	airspeed = velocity.length()
	var local_velocity := basis.transposed() * velocity
	var forward_speed := maxf(-local_velocity.z, 0.0)
	angle_of_attack = atan2(-local_velocity.y, maxf(forward_speed, 0.1))
	_update_altitude(state.transform.origin)
	var sink := gear.integrate(state, self, pilot.brakes or is_crashed or is_destroyed)
	if gear.contact_count == 0:
		airborne_time += dt
	else:
		if sink < -gear.fatal_sink_speed and airborne_time > 0.25:
			_crash("Hard landing · excessive sink rate")
		airborne_time = 0.0
	# Body and wing collision catch belly landings, terrain, and buildings.
	if state.get_contact_count() > 0 and not is_crashed and not is_destroyed:
		for i in range(state.get_contact_count()):
			var impact := state.get_contact_local_velocity_at_position(i).length()
			if not gear.extended or impact > 9.0 or gear.contact_count == 0:
				_crash("Airframe struck the ground" if gear.extended else "Landing gear was retracted")
				break
	if is_crashed:
		state.apply_central_force(-velocity * mass * 2.0)
		state.apply_torque(-state.angular_velocity * 20000.0)
		return
	var q := 0.5 * air_density * forward_speed * forward_speed
	var alpha_limit := deg_to_rad(stall_angle_degrees)
	var alpha_abs := absf(angle_of_attack)
	var stall_blend := smoothstep(alpha_limit, alpha_limit + deg_to_rad(14.0), alpha_abs)
	var cl := clampf(lift_at_zero_alpha + lift_slope * angle_of_attack, -1.5, 1.8)
	# This forgiving stall fades lift rather than imposing a scripted fall.
	# Residual lift and pitch authority allow recovery by lowering the nose.
	cl *= lerpf(1.0, 0.22, stall_blend)
	stalled = gear.contact_count == 0 and (airspeed < stall_speed or alpha_abs > alpha_limit)
	var direction := velocity.normalized() if airspeed > 0.1 else -basis.z
	var lift_direction := basis.y.slide(direction).normalized()
	state.apply_central_force(lift_direction * q * wing_area * cl)
	var drag_coefficient := parasite_drag + induced_drag * cl * cl + stall_blend * 0.28
	if gear.extended:
		drag_coefficient += 0.026
	state.apply_central_force(-direction * 0.5 * air_density * airspeed * airspeed * wing_area * drag_coefficient)
	# Propeller thrust loses effectiveness with speed; no velocity cap or
	# direct transform movement is used in normal flight.
	var thrust := engine_thrust * pilot.throttle / (1.0 + forward_speed / 130.0) if not is_destroyed else 0.0
	state.apply_central_force(-basis.z * thrust)
	# Vertical fin resists sideslip. Forces change the actual travel direction.
	state.apply_central_force(-basis.x * local_velocity.x * (180.0 + forward_speed * 22.0))
	var authority := clampf(forward_speed / 45.0, 0.12, 1.5)
	var local_omega := basis.transposed() * state.angular_velocity
	var torque := Vector3(pilot.pitch * pitch_torque, pilot.rudder * rudder_torque, pilot.roll * roll_torque) * authority
	if is_destroyed:
		# Dead engine/controls, but passive lift, drag, gravity and angular
		# stability still act. Do not freeze or scripted-translate the wreck.
		torque = Vector3.ZERO
	# Mild weathercock stability and nose-down stall tendency, not an autopilot.
	if gear.contact_count == 0:
		torque.x += -angle_of_attack * 5500.0 * authority - stall_blend * 8000.0
		torque.y -= local_velocity.x * 650.0
		# Banking requests the yaw rate of an approximate coordinated turn.
		# Lift remains tilted with the wings and supplies the turning force.
		var bank_sine := clampf(basis.x.y, -0.85, 0.85)
		var turn_rate := 9.81 * bank_sine / maxf(airspeed, 25.0) * coordinated_turn
		torque.y += (turn_rate - state.angular_velocity.y) * 48000.0
	else:
		# Rudder and differential steering share A/D for manageable taxiing.
		torque.y += pilot.rudder * 14000.0 * clampf(airspeed / 8.0, 0.0, 1.0)
		torque.z *= 0.15
	var damping := Vector3(inertia.x, inertia.y, inertia.z) * angular_response
	torque -= local_omega * damping
	state.apply_torque(basis * torque)

func _update_altitude(origin: Vector3) -> void:
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 10000.0, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	altitude = maxf(origin.y - float(hit.position.y), 0.0) if not hit.is_empty() else maxf(origin.y, 0.0)

func _crash(reason: String) -> void:
	if is_crashed or is_destroyed:
		return
	is_crashed = true
	crash_reason = reason
	pilot.throttle = 0.0
	crashed.emit(reason)

func _process(delta: float) -> void:
	model.animate(delta, pilot.throttle, gear, is_crashed or is_destroyed)
