class_name EnemyPilot
extends Node
## Commands only: the shared RigidBody aerodynamics perform every manoeuvre.
@export_group("Encounter difficulty")
@export var combat_enabled: bool = true
@export var cruise_speed: float = 58.0
@export var engage_speed_bonus: float = 18.0
@export var patrol_radius: float = 450.0
@export var detection_range: float = 3200.0
@export var pursuit_release_range: float = 7500.0
@export var minimum_player_agl: float = 12.0
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
@export_group("Energy and defensive tactics (simplified)")
@export var rear_threat_range: float = 650.0
@export var rear_threat_cone_degrees: float = 55.0
@export var evade_on_rear_threat: bool = true
@export var defensive_cooldown: float = 6.0
@export var tactical_height_change: float = 35.0
@export var pursuit_prediction_seconds: float = 4.0
@export var overshoot_closing_speed: float = 18.0
@export var maximum_tactical_bank_degrees: float = 55.0
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
@export_group("Damage compensation through pilot commands")
@export var damage_trim_gain: float = 0.45
@export_range(0, 1, 0.01) var maximum_damage_trim: float = 0.55
@export_range(0.05, 1, 0.01) var compensation_authority_floor: float = 0.25
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
var roll_trim: float = 0.0
var pitch_trim: float = 0.0
var combat_unlocked: bool = false
var tracking_target: bool = false
var defensive_clock: float = 0
var tactic: String = "PATROL"
var break_tactic: String = "BREAK"
var last_break_side: float = 1

func _ready() -> void:
	aircraft.health.changed.connect(_health_changed)
	reset()

func reset() -> void:
	mode = "PATROL"
	tactic = "PATROL"
	combat_unlocked = false
	tracking_target = false
	defensive_clock = 0
	last_break_side = 1
	break_tactic = "BREAK"
	break_point = Vector3.ZERO
	roll_trim = 0
	pitch_trim = 0
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

func _begin_evade(defensive: bool = false) -> void:
	break_timer = evade_duration
	var side: float = -1.0 if rng.randf() < 0.5 else 1.0
	if defensive and is_instance_valid(target):
		# Break toward the attacking side, forcing it to turn across our path.
		# A centred pursuer gets alternating breaks, a shallow scissors pattern.
		var attacker_side: float = aircraft.to_local(target.global_position).x
		side = signf(attacker_side) if absf(attacker_side) > 8 else -last_break_side
	last_break_side = side
	var height_change: float = tactical_height_change
	if defensive and aircraft.altitude > minimum_agl + terrain_margin + tactical_height_change:
		height_change = -tactical_height_change # shallow energy-preserving descending break
	break_point = aircraft.global_position - aircraft.global_basis.z * 350.0 + aircraft.global_basis.x * 450.0 * side + Vector3.UP * height_change
	break_tactic = "BREAK LEFT" if side < 0 else "BREAK RIGHT"
	defensive_clock = defensive_cooldown

func _player_airborne() -> bool:
	return combat_enabled and is_instance_valid(target) and not target.is_destroyed and not target.is_crashed and target.gear.contact_count == 0 and target.altitude > minimum_player_agl

func engagement_ready() -> bool:
	return _player_airborne() and (combat_unlocked or airborne_timer >= grace_period)

func _physics_process(delta: float) -> void:
	aircraft.pilot.fire = false
	aircraft.guns.use_assisted_aim = false
	if aircraft.reset_pending:
		return
	if aircraft.is_destroyed or aircraft.is_crashed:
		mode = "DESTROYED"
		aircraft.pilot.reset_commands()
		return
	# Speed is no longer an acquisition gate: slow climbs and damaged fighters
	# should not make the AI forget them. The grace unlock stays for this life.
	var can_engage: bool = _player_airborne()
	airborne_timer = airborne_timer + delta if can_engage else 0.0
	combat_unlocked = combat_unlocked or (can_engage and airborne_timer >= grace_period)
	burst_clock += delta
	break_timer = maxf(break_timer - delta, 0.0)
	defensive_clock = maxf(defensive_clock - delta, 0.0)
	var aim: Vector3 = _patrol_point()
	var distance: float = aircraft.global_position.distance_to(target.global_position) if is_instance_valid(target) else INF
	if not can_engage or distance > maxf(pursuit_release_range, detection_range):
		tracking_target = false
	elif engagement_ready() and distance <= detection_range:
		tracking_target = true
	var pursuing: bool = engagement_ready() and tracking_target
	mode = "PATROL"
	tactic = "TAKEOFF GRACE" if can_engage and not engagement_ready() else "PATROL"
	if pursuing:
		mode = "ENGAGE"
		aim = _pursuit_point()
		if distance < close_pass_distance and break_timer <= 0.0:
			_begin_evade()
		elif evade_on_rear_threat and break_timer <= 0 and defensive_clock <= 0 and _rear_threat():
			_begin_evade(true)
	if break_timer > 0:
		mode = "EVADE"
		tactic = break_tactic
		aim = break_point
	scan_clock -= delta
	if scan_clock <= 0:
		_scan_terrain()
		scan_clock = 0.15
	if terrain_avoiding:
		mode = "EVADE"
		tactic = "TERRAIN AVOIDANCE"
		aim = avoidance_point
	elif pursuing and break_timer <= 0:
		# Navigation predicts a flight intercept; gun lead remains a separate,
		# shorter ballistic prediction. Never bend forward rounds toward a yo-yo.
		var gun_aim: Vector3 = _lead_point()
		var angle: float = (-aircraft.global_basis.z).angle_to((gun_aim - aircraft.global_position).normalized())
		var cycle: float = maxf(burst_duration + burst_rest, 0.1)
		var index: int = floori(burst_clock / cycle)
		if index != burst_index:
			burst_index = index
			aim_bias = Vector2(rng.randf_range(-aim_error_degrees, aim_error_degrees), rng.randf_range(-aim_error_degrees, aim_error_degrees))
		var in_burst: bool = fposmod(burst_clock, cycle) < burst_duration
		if distance < firing_range and angle < deg_to_rad(firing_cone_degrees) and _clear_line_of_sight():
			aircraft.pilot.fire = in_burst
			aircraft.guns.use_assisted_aim = in_burst
			var biased: Vector3 = (gun_aim - aircraft.global_position).rotated(aircraft.global_basis.x, deg_to_rad(aim_bias.x)).rotated(aircraft.global_basis.y, deg_to_rad(aim_bias.y))
			aircraft.guns.assisted_aim = aircraft.global_position + biased
			aircraft.guns.max_assist_degrees = firing_cone_degrees
	_fly_toward(aim, delta)

func _rear_threat() -> bool:
	var offset: Vector3 = target.global_position - aircraft.global_position
	if offset.length() > rear_threat_range or aircraft.global_basis.z.angle_to(offset) > deg_to_rad(rear_threat_cone_degrees):
		return false
	# A plane behind us but flying away is not an attacker.
	return (-target.global_basis.z).angle_to(-offset) < deg_to_rad(25)

func _pursuit_point() -> Vector3:
	var offset: Vector3 = target.global_position - aircraft.global_position
	var prediction: float = clampf(offset.length() / maxf(aircraft.airspeed, 30) * 0.35, 0.15, pursuit_prediction_seconds)
	var point: Vector3 = target.global_position + target.linear_velocity * prediction
	if offset.length() < 900:
		point = _lead_point() # transition to nose alignment for the firing pass
	tactic = "INTERCEPT"
	var alignment: float = (-aircraft.global_basis.z).angle_to(offset)
	var closing: float = (aircraft.linear_velocity - target.linear_velocity).dot(offset.normalized())
	# Simplified yo-yos: climb to reduce excess closure, descend to trade height
	# for speed in a turning pursuit. These are goals, not scripted manoeuvres.
	if offset.length() < 300 and alignment < deg_to_rad(55) and closing > overshoot_closing_speed and aircraft.airspeed > 50:
		point.y += tactical_height_change
		tactic = "HIGH YO-YO"
	elif offset.length() < 1000 and alignment > deg_to_rad(15) and alignment < deg_to_rad(75) and target.airspeed > aircraft.airspeed + 4 and aircraft.altitude > minimum_agl + terrain_margin + tactical_height_change:
		point.y -= tactical_height_change
		tactic = "LOW YO-YO"
	return point

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
	var bank_limit: float = maximum_tactical_bank_degrees if mode in ["ENGAGE", "EVADE"] and not terrain_avoiding else maximum_bank_degrees
	var desired_bank: float = clampf(heading_error * 1.4, -deg_to_rad(bank_limit), deg_to_rad(bank_limit))
	var damage: AircraftDamage = aircraft.components
	var impaired: bool = damage.lift_factor() < 0.999 or damage.cockpit_factor() < 0.999 or damage.elevator_factor() < 0.999
	var omega: Vector3 = aircraft.global_basis.transposed() * aircraft.angular_velocity
	if impaired:
		# Integrate the measured bank error to counter a persistent asymmetric
		# wing moment. Trim remains a normal, bounded and slewed roll command.
		roll_trim = clampf(roll_trim + (desired_bank - bank) * damage_trim_gain * delta, -maximum_damage_trim, maximum_damage_trim)
	else:
		roll_trim = move_toward(roll_trim, 0, delta)
	var roll: float = clampf(((desired_bank - bank) * 4.0 - omega.z * 0.6 + roll_trim) / maxf(damage.cockpit_factor(), compensation_authority_floor), -1, 1)
	var height: float = maxf(point.y, Airfield.height_at(aircraft.global_position.x, aircraft.global_position.z) + minimum_agl)
	if impaired:
		pitch_trim = clampf(pitch_trim + (height - aircraft.global_position.y) * damage_trim_gain * delta * 0.002, -0.07, 0.07)
	else:
		pitch_trim = move_toward(pitch_trim, 0, delta)
	var desired_pitch: float = clampf(0.02 + pitch_trim + (height - aircraft.global_position.y) * 0.008, -0.22, 0.3)
	if damage.power_factor() < 0.25 and aircraft.altitude > minimum_agl + terrain_margin:
		desired_pitch = -0.10 # powerless/weak-engine glide; cannot maintain height forever
	if aircraft.airspeed < 36.0 / sqrt(maxf(damage.lift_factor(), 0.1)) and aircraft.altitude > minimum_agl + terrain_margin:
		desired_pitch = -0.17 # simplified, recoverable stall response
	var pitch: float = asin(clampf(forward.y, -1.0, 1.0))
	var pitch_command: float = clampf(((desired_pitch - pitch) * 5.0 - omega.x * 0.7) / maxf(damage.elevator_factor() * damage.cockpit_factor(), compensation_authority_floor), -1, 1)
	var rudder: float = clampf(heading_error * 0.15 / maxf(damage.rudder_factor() * damage.cockpit_factor(), compensation_authority_floor), -0.6 if damage.rudder_factor() < 0.999 else -0.3, 0.6 if damage.rudder_factor() < 0.999 else 0.3)
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
	if mode == "ENGAGE" and is_instance_valid(target):
		var spacing: float = aircraft.global_position.distance_to(target.global_position)
		# Close faster at long range, match speed near the firing pass instead
		# of charging past at full power and circling without a shot.
		wanted_speed = clampf(target.airspeed + clampf((spacing - 180) * 0.025, 0, engage_speed_bonus), cruise_speed, 85)
	aircraft.pilot.throttle = 1.0 if terrain_avoiding else clampf((0.6 + (wanted_speed - aircraft.airspeed) * 0.025) / maxf(damage.power_factor(), compensation_authority_floor), 0.2, 1.0)
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
