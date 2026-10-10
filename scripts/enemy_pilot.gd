class_name EnemyPilot
extends Node
## Commands only: the shared RigidBody aerodynamics perform every manoeuvre.
@export_group("Encounter difficulty")
@export var combat_enabled: bool = true
@export var cruise_speed: float = 58.0
@export var engage_speed_bonus: float = 8.0
@export var patrol_radius: float = 450.0
@export var detection_range: float = 1800.0
@export var firing_range: float = 650.0
@export var firing_cone_degrees: float = 6.0
@export var grace_period: float = 8.0
@export var burst_duration: float = 0.75
@export var burst_rest: float = 1.25
@export var aim_error_degrees: float = 0.18
@export var aim_seed: int = 1942
@export var evade_on_damage: bool = true
@export var evade_duration: float = 3.0
@export var close_pass_distance: float = 115.0
@export_group("Flight and avoidance")
@export var minimum_agl: float = 65.0
@export var terrain_lookahead_seconds: float = 5.0
@export var terrain_margin: float = 20.0
@export var command_slew_rate: float = 2.5
@export var maximum_bank_degrees: float = 46.0
@export var maximum_pitch_rate: float = 0.45
@export var maximum_roll_rate: float = 0.7
@export var maximum_yaw_rate: float = 0.3
@export var boundary_margin: float = 500.0
var aircraft: FlightAircraft
var target: FlightAircraft
var mode: String = "PATROL"
var airborne_timer: float = 0.0
var burst_clock: float = 0.0
var break_timer: float = 0.0
var break_point: Vector3 = Vector3.ZERO
var patrol_center: Vector3 = Vector3(0, 160, 0)
var terrain_avoiding: bool = false
var avoidance_point: Vector3 = Vector3.ZERO
var scan_clock: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var burst_index: int = -1
var aim_bias: Vector2 = Vector2.ZERO
var previous_hp: float = 100.0

func _ready() -> void:
	aircraft.health.changed.connect(_health_changed)
	reset()

func reset() -> void:
	mode = "PATROL"
	airborne_timer = 0.0
	burst_clock = 0.0
	break_timer = 0.0
	scan_clock = 0.0
	terrain_avoiding = false
	previous_hp = aircraft.health.hp
	rng.seed = aim_seed
	burst_index = -1
	aim_bias = Vector2.ZERO
	aircraft.pilot.reset_commands()
	aircraft.guns.use_assisted_aim = false

func _health_changed(hp: float, _maximum: float) -> void:
	if evade_on_damage and hp > 0 and hp < previous_hp and break_timer <= 0:
		_begin_evade()
	previous_hp = hp

func _begin_evade() -> void:
	break_timer = evade_duration
	var side: float = -1.0 if rng.randf() < 0.5 else 1.0
	break_point = aircraft.global_position - aircraft.global_basis.z * 450.0 + aircraft.global_basis.x * 300.0 * side + Vector3.UP * 35.0

func _physics_process(delta: float) -> void:
	aircraft.pilot.fire = false
	aircraft.guns.use_assisted_aim = false
	if aircraft.reset_pending:
		return
	if aircraft.is_destroyed or aircraft.is_crashed:
		mode = "DESTROYED"
		aircraft.pilot.reset_commands()
		return
	# Grace counts continuous safe airborne time, never time sitting on the runway.
	var can_engage: bool = combat_enabled and is_instance_valid(target) and not target.is_destroyed and not target.is_crashed and target.gear.contact_count == 0 and target.altitude > 25.0 and target.airspeed > 35.0
	airborne_timer = airborne_timer + delta if can_engage else 0.0
	burst_clock += delta
	break_timer = maxf(break_timer - delta, 0.0)
	var aim: Vector3 = _patrol_point()
	var distance: float = aircraft.global_position.distance_to(target.global_position) if is_instance_valid(target) else INF
	var pursuing: bool = can_engage and airborne_timer >= grace_period and distance < detection_range
	mode = "PATROL"
	if pursuing:
		mode = "ENGAGE"
		aim = _lead_point()
		if distance < close_pass_distance and break_timer <= 0.0:
			_begin_evade()
	if break_timer > 0:
		mode = "EVADE"
		aim = break_point
	scan_clock -= delta
	if scan_clock <= 0:
		_scan_terrain()
		scan_clock = 0.15
	if terrain_avoiding:
		mode = "EVADE"
		aim = avoidance_point
	elif pursuing and break_timer <= 0:
		var angle: float = (-aircraft.global_basis.z).angle_to((aim - aircraft.global_position).normalized())
		var cycle: float = maxf(burst_duration + burst_rest, 0.1)
		var index: int = floori(burst_clock / cycle)
		if index != burst_index:
			burst_index = index
			aim_bias = Vector2(rng.randf_range(-aim_error_degrees, aim_error_degrees), rng.randf_range(-aim_error_degrees, aim_error_degrees))
		var in_burst: bool = fposmod(burst_clock, cycle) < burst_duration
		if distance < firing_range and angle < deg_to_rad(firing_cone_degrees) and _clear_line_of_sight():
			aircraft.pilot.fire = in_burst
			aircraft.guns.use_assisted_aim = in_burst
			var biased: Vector3 = (aim - aircraft.global_position).rotated(aircraft.global_basis.x, deg_to_rad(aim_bias.x)).rotated(aircraft.global_basis.y, deg_to_rad(aim_bias.y))
			aircraft.guns.assisted_aim = aircraft.global_position + biased
			aircraft.guns.max_assist_degrees = firing_cone_degrees
	_fly_toward(aim, delta)

func _scan_terrain() -> void:
	terrain_avoiding = false
	var position: Vector3 = aircraft.global_position
	var flat_forward: Vector3 = (-aircraft.global_basis.z * Vector3(1, 0, 1)).normalized()
	var right: Vector3 = flat_forward.cross(Vector3.UP)
	var horizon: float = clampf(aircraft.airspeed * terrain_lookahead_seconds, 120, 450)
	var highest: float = Airfield.height_at(position.x, position.z)
	var space: PhysicsDirectSpaceState3D = aircraft.get_world_3d().direct_space_state
	# Downward rays sample actual terrain/buildings in a corridor ahead, including
	# wing tips. Forecast clearance using velocity, not only current altitude.
	for fraction in [0.0, 0.5, 1.0]:
		for lane in [-8.0, 0.0, 8.0]:
			var point: Vector3 = position + flat_forward * horizon * fraction + right * lane
			var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 500, point + Vector3.DOWN * 1500, 1)
			var hit: Dictionary = space.intersect_ray(ray)
			var ground: float = float(hit.position.y) if not hit.is_empty() else Airfield.height_at(point.x, point.z)
			highest = maxf(highest, ground)
			var predicted_y: float = position.y + minf(aircraft.linear_velocity.y, 0) * terrain_lookahead_seconds * fraction
			if predicted_y < ground + minimum_agl:
				terrain_avoiding = true
	avoidance_point = position + flat_forward * horizon
	avoidance_point.y = maxf(position.y + terrain_margin, highest + minimum_agl + terrain_margin)
	# A horizontal probe catches tall obstacles before the next ground sample.
	var obstruction: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(position, position + flat_forward * horizon, 1))
	if not obstruction.is_empty():
		terrain_avoiding = true
		var left_goal: Vector3 = position + (flat_forward - right * 1.5) * horizon
		var right_goal: Vector3 = position + (flat_forward + right * 1.5) * horizon
		var left_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(position, left_goal, 1))
		var right_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(position, right_goal, 1))
		var left_clearance: float = position.distance_to(left_hit.position) if not left_hit.is_empty() else INF
		var right_clearance: float = position.distance_to(right_hit.position) if not right_hit.is_empty() else INF
		avoidance_point = left_goal if left_clearance >= right_clearance else right_goal
		avoidance_point.y = maxf(position.y + terrain_margin, highest + minimum_agl + terrain_margin)
	if maxf(absf(position.x), absf(position.z)) > Airfield.EXTENT - boundary_margin:
		terrain_avoiding = true
		avoidance_point = patrol_center
		avoidance_point.y = maxf(patrol_center.y, highest + minimum_agl + terrain_margin)

func _patrol_point() -> Vector3:
	var radial: Vector3 = aircraft.global_position - patrol_center
	radial.y = 0.0
	if radial.length_squared() < 1.0:
		radial = Vector3.LEFT * patrol_radius
	var tangent: Vector3 = Vector3(-radial.z, 0, radial.x).normalized()
	var point: Vector3 = aircraft.global_position + tangent * 180.0 - radial.normalized() * (radial.length() - patrol_radius) * 2.0
	point.y = patrol_center.y
	return point

func _fly_toward(point: Vector3, delta: float) -> void:
	var forward: Vector3 = -aircraft.global_basis.z
	var direction: Vector3 = point - aircraft.global_position
	var heading: float = atan2(-forward.x, -forward.z)
	var desired_heading: float = atan2(-direction.x, -direction.z)
	var heading_error: float = wrapf(desired_heading - heading, -PI, PI)
	var bank: float = asin(clampf(aircraft.global_basis.x.y, -1.0, 1.0))
	var desired_bank: float = clampf(heading_error * 1.4, -deg_to_rad(maximum_bank_degrees), deg_to_rad(maximum_bank_degrees))
	var omega: Vector3 = aircraft.global_basis.transposed() * aircraft.angular_velocity
	var roll: float = clampf((desired_bank - bank) * 4.0 - omega.z * 0.6, -1, 1)
	var height: float = maxf(point.y, Airfield.height_at(aircraft.global_position.x, aircraft.global_position.z) + minimum_agl)
	var desired_pitch: float = clampf(0.02 + (height - aircraft.global_position.y) * 0.008, -0.22, 0.3)
	if aircraft.airspeed < 36.0 and aircraft.altitude > minimum_agl + terrain_margin:
		desired_pitch = -0.17 # simplified, recoverable stall response
	var pitch: float = asin(clampf(forward.y, -1.0, 1.0))
	var pitch_command: float = clampf((desired_pitch - pitch) * 5.0 - omega.x * 0.7, -1, 1)
	var rudder: float = clampf(heading_error * 0.15, -0.3, 0.3)
	# Soft rate limits oppose excessive angular motion through control torque.
	# No transform or velocity is assigned by the AI.
	if absf(omega.z) > maximum_roll_rate:
		roll = -signf(omega.z)
	if absf(omega.x) > maximum_pitch_rate:
		pitch_command = -signf(omega.x)
	if absf(omega.y) > maximum_yaw_rate:
		rudder = -signf(omega.y)
	var step: float = command_slew_rate * delta
	aircraft.pilot.roll = move_toward(aircraft.pilot.roll, roll, step)
	aircraft.pilot.pitch = move_toward(aircraft.pilot.pitch, pitch_command, step)
	aircraft.pilot.rudder = move_toward(aircraft.pilot.rudder, rudder, step)
	var wanted_speed: float = cruise_speed + (engage_speed_bonus if mode == "ENGAGE" else 0.0)
	aircraft.pilot.throttle = 1.0 if terrain_avoiding else clampf(0.6 + (wanted_speed - aircraft.airspeed) * 0.025, 0.2, 1.0)
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
	if not is_instance_valid(target):
		return false
	# Each wing gun needs an unobstructed path, not just the aircraft centre.
	for port in aircraft.model.gun_ports:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(port.global_position, target.global_position, 7, [aircraft.get_rid()])
		var hit: Dictionary = aircraft.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider != target:
			return false
	return true
