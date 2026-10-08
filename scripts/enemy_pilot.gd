class_name EnemyPilot
extends Node
## AI changes pilot commands only. RigidBody forces/torques perform all flight.
@export var combat_enabled: bool = true
@export var cruise_speed: float = 58.0
@export var patrol_radius: float = 450.0
@export var detection_range: float = 1800.0
@export var firing_range: float = 650.0
@export var firing_cone_degrees: float = 6.0
@export var grace_period: float = 8.0
@export var burst_duration: float = 0.75
@export var burst_rest: float = 1.25
@export var minimum_agl: float = 65.0
var aircraft: FlightAircraft
var target: FlightAircraft
var mode: String = "PATROL"
var airborne_timer: float = 0.0
var burst_clock: float = 0.0
var break_timer: float = 0.0
var break_point: Vector3 = Vector3.ZERO
var patrol_center: Vector3 = Vector3(0, 160, 0)

func reset() -> void:
	mode = "PATROL"
	airborne_timer = 0.0
	burst_clock = 0.0
	break_timer = 0.0
	aircraft.pilot.reset_commands()
	aircraft.guns.use_assisted_aim = false

func _physics_process(delta: float) -> void:
	aircraft.pilot.fire = false
	if aircraft.reset_pending:
		return
	if aircraft.is_destroyed or aircraft.is_crashed:
		mode = "DOWNED"
		aircraft.pilot.reset_commands()
		return
	var can_engage: bool = combat_enabled and is_instance_valid(target) and not target.is_destroyed and not target.is_crashed and target.gear.contact_count == 0 and target.altitude > 25.0 and target.airspeed > 35.0
	airborne_timer = airborne_timer + delta if can_engage else 0.0
	burst_clock += delta
	break_timer = maxf(break_timer - delta, 0.0)
	var aim: Vector3 = _patrol_point()
	var distance: float = aircraft.global_position.distance_to(target.global_position) if is_instance_valid(target) else INF
	var pursuing: bool = can_engage and airborne_timer >= grace_period and distance < detection_range
	mode = "PATROL"
	if pursuing:
		mode = "PURSUIT"
		aim = _lead_point()
		if distance < 115.0 and break_timer <= 0.0:
			break_timer = 3.0
			break_point = aircraft.global_position - aircraft.global_basis.z * 450.0 + aircraft.global_basis.x * 300.0 + Vector3.UP * 35.0
		if break_timer > 0.0:
			mode = "BREAK"
			aim = break_point
		else:
			var angle: float = (-aircraft.global_basis.z).angle_to((aim - aircraft.global_position).normalized())
			var in_burst: bool = fposmod(burst_clock, maxf(burst_duration + burst_rest, 0.1)) < burst_duration
			if distance < firing_range and angle < deg_to_rad(firing_cone_degrees) and _clear_line_of_sight():
				mode = "ATTACK"
				aircraft.pilot.fire = in_burst
				aircraft.guns.use_assisted_aim = true
				aircraft.guns.assisted_aim = aim
				aircraft.guns.max_assist_degrees = firing_cone_degrees
	if not aircraft.pilot.fire:
		aircraft.guns.use_assisted_aim = false
	_fly_toward(aim)

func _patrol_point() -> Vector3:
	var radial: Vector3 = aircraft.global_position - patrol_center
	radial.y = 0.0
	if radial.length_squared() < 1.0:
		radial = Vector3.LEFT * patrol_radius
	var tangent: Vector3 = Vector3(-radial.z, 0, radial.x).normalized()
	var point: Vector3 = aircraft.global_position + tangent * 180.0 - radial.normalized() * (radial.length() - patrol_radius) * 2.0
	point.y = patrol_center.y
	return point

func _fly_toward(point: Vector3) -> void:
	var forward: Vector3 = -aircraft.global_basis.z
	var direction: Vector3 = point - aircraft.global_position
	var heading: float = atan2(-forward.x, -forward.z)
	var desired_heading: float = atan2(-direction.x, -direction.z)
	var heading_error: float = wrapf(desired_heading - heading, -PI, PI)
	var bank: float = asin(clampf(aircraft.global_basis.x.y, -1.0, 1.0))
	var desired_bank: float = clampf(heading_error * 1.4, -0.8, 0.8)
	var omega: Vector3 = aircraft.global_basis.transposed() * aircraft.angular_velocity
	aircraft.pilot.roll = clampf((desired_bank - bank) * 4.0 - omega.z * 0.6, -1, 1)
	var ground: float = Airfield.height_at(aircraft.global_position.x, aircraft.global_position.z)
	var height: float = maxf(point.y, ground + minimum_agl)
	var desired_pitch: float = clampf(0.02 + (height - aircraft.global_position.y) * 0.008, -0.22, 0.3)
	if aircraft.airspeed < 36.0 and aircraft.altitude > minimum_agl:
		desired_pitch = -0.17 # recover speed instead of endlessly pulling into a stall
	var pitch: float = asin(clampf(forward.y, -1.0, 1.0))
	aircraft.pilot.pitch = clampf((desired_pitch - pitch) * 5.0 - omega.x * 0.7, -1, 1)
	aircraft.pilot.rudder = clampf(heading_error * 0.15, -0.3, 0.3)
	aircraft.pilot.throttle = clampf(0.6 + (cruise_speed - aircraft.airspeed) * 0.025, 0.2, 1.0)
	aircraft.pilot.brakes = false

func _lead_point() -> Vector3:
	var offset: Vector3 = target.global_position - aircraft.global_position
	var relative_velocity: Vector3 = target.linear_velocity - aircraft.linear_velocity
	var speed: float = aircraft.guns.bullet_speed
	var a: float = relative_velocity.length_squared() - speed * speed
	var b: float = 2.0 * offset.dot(relative_velocity)
	var c: float = offset.length_squared()
	var time: float = offset.length() / maxf(speed, 1.0)
	var discriminant: float = b * b - 4.0 * a * c
	if absf(a) > 0.001 and discriminant >= 0:
		var t0: float = (-b - sqrt(discriminant)) / (2.0 * a)
		var t1: float = (-b + sqrt(discriminant)) / (2.0 * a)
		if t0 > 0 and t1 > 0:
			time = minf(t0, t1)
		elif maxf(t0, t1) > 0:
			time = maxf(t0, t1)
	time = clampf(time, 0.01, aircraft.guns.bullet_lifetime * 0.9)
	# Subtract shooter velocity because bullets inherit it in WingGuns.
	return target.global_position + relative_velocity * time

func _clear_line_of_sight() -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(aircraft.model.gun_ports[0].global_position, target.global_position, 7, [aircraft.get_rid()])
	var hit: Dictionary = aircraft.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == target

