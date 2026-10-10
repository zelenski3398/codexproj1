class_name RearGunner
extends Node
## Human observation -> estimated whole-aircraft intercept -> physical traverse.
## No access to target velocity or component positions. Shots retain real flight
## time/dispersion and shared damage. No arbitrary maximum engagement distance.
@export_group("Gunner skill")
@export_enum("Cadet", "Pilot", "Ace") var skill_level: int = 1
@export var skill_override: GunnerSkillProfile
@export var aim_seed: int = 1943
@export_group("Mechanical mount")
@export var enabled: bool = true
@export var minimum_distance: float = 18.0
@export var horizontal_arc_degrees: float = 70.0
@export var minimum_elevation_degrees: float = -12.0
@export var maximum_elevation_degrees: float = 60.0
@export var tracking_rate_degrees: float = 75.0 # mechanical cap; humans are slower
@export var firing_alignment_degrees: float = 1.5
@export var burst_duration: float = 0.45
@export var burst_rest: float = 1.4
@export_group("MG 15-style weapon (unchanged ballistics)")
@export var rounds_per_second: float = 16.67
@export var bullet_speed: float = 765.0
@export var bullet_damage: float = 1.5
@export var bullet_lifetime: float = 1.15
@export var spread_degrees: float = 0.15
var aircraft: EnemyAircraft
var guns: WingGuns
var yaw: float = 0
var elevation: float = deg_to_rad(12)
var aim_point: Vector3 = Vector3.ZERO
var firing: bool = false
var status: String = "WAITING FOR TAKEOFF"
var burst_clock: float = 0
var cycle_index: int = -1
var aim_bias: Vector2 = Vector2.ZERO
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var visibility: float = 0
var angular_motion: float = 0
var motion_penalty_degrees: float = 0
var error_degrees: float = 0
var engagement_distance: float = 0
var estimated_flight_time: float = 0
var perceived_position: Vector3 = Vector3.ZERO
var perceived_velocity: Vector3 = Vector3.ZERO
var observation_count: int = 0
var _clock: float = 0
var _visible_seconds: float = 0
var _lost_seconds: float = 0
var _sample_clock: float = 0
var _sample_positions: Array[Vector3] = []
var _sample_times: Array[float] = []
var _perceived_time: float = -1
var _previous_direction: Vector3 = Vector3.ZERO
var _previous_velocity: Vector3 = Vector3.ZERO
var _burst_position: Vector3 = Vector3.ZERO
var _burst_velocity: Vector3 = Vector3.ZERO
var _burst_time: float = 0
var _burst_active: bool = false
var _lead_bias: float = 0
var _range_bias: float = 0
var _silhouette_bias: Vector2 = Vector2.ZERO
var _wobble: Vector2 = Vector2.ZERO
var _wobble_goal: Vector2 = Vector2.ZERO
var _wobble_clock: float = 0
var _profile: GunnerSkillProfile

func skill_profile() -> GunnerSkillProfile:
	if skill_override != null:
		return skill_override
	match skill_level:
		0: return preload("res://gunner_profiles/cadet.tres")
		2: return preload("res://gunner_profiles/ace.tres")
	return preload("res://gunner_profiles/pilot.tres")

func set_skill(level: int) -> void:
	skill_level = clampi(level, 0, 2)
	skill_override = null
	_clear_observation()
	_profile = skill_profile()
	cease_fire()
	status = "REACQUIRING"

func _ready() -> void:
	guns = WingGuns.new()
	guns.name = "RearMG15"
	guns.aircraft = aircraft
	guns.externally_controlled = true
	guns.forward_from_port = true
	guns.firing_ports = [(aircraft.model as StukaModel).rear_muzzle]
	guns.convergence_distance = 0
	guns.pool_capacity = 128
	guns.shot_clearance = Callable(self, "shot_has_clearance")
	guns.telemetry_target = aircraft.target
	add_child(guns)
	guns.pool.tracer_material.albedo_color = Color("ff8050")
	reset()

func reset() -> void:
	_clock = 0
	burst_clock = 0
	cycle_index = -1
	aim_bias = Vector2.ZERO
	_silhouette_bias = Vector2.ZERO
	_lead_bias = 0
	_range_bias = 0
	_wobble = Vector2.ZERO
	_wobble_clock = 0
	rng.seed = aim_seed
	yaw = 0
	elevation = deg_to_rad(12)
	firing = false
	status = "WAITING FOR TAKEOFF"
	_clear_observation()
	_profile = skill_profile()
	_previous_velocity = aircraft.linear_velocity
	(aircraft.model as StukaModel).set_rear_gun_angles(yaw, elevation)
	guns.reset()
	guns.rng.seed = aim_seed + 17

func _clear_observation() -> void:
	_visible_seconds = 0
	_lost_seconds = 0
	_sample_clock = 0
	_sample_positions.clear()
	_sample_times.clear()
	_perceived_time = -1
	perceived_velocity = Vector3.ZERO
	observation_count = 0
	_previous_direction = Vector3.ZERO
	_burst_active = false
	cycle_index = -1

func cease_fire() -> void:
	firing = false
	guns.external_fire = false

func muzzle() -> Marker3D:
	return (aircraft.model as StukaModel).rear_muzzle

func _lose_sight(delta: float, reason: String) -> void:
	status = reason
	_previous_direction = Vector3.ZERO
	_lost_seconds += delta
	if _lost_seconds >= _profile.reacquisition_seconds:
		_clear_observation()

func _physics_process(delta: float) -> void:
	cease_fire()
	_clock += delta
	# Sample own acceleration every tick, including loss of sight. Otherwise a
	# velocity change during occlusion would be misread as a one-tick shock.
	var acceleration: float = (aircraft.linear_velocity - _previous_velocity).length() / maxf(delta, 0.0001)
	_previous_velocity = aircraft.linear_velocity
	var profile: GunnerSkillProfile = skill_profile()
	if profile != _profile:
		_profile = profile
		_clear_observation()
	if not enabled or aircraft.is_destroyed or aircraft.is_crashed or aircraft.reset_pending:
		status = "OFFLINE"
		return
	if aircraft.components.integrity_ratio(&"cockpit") <= 0:
		status = "CREW DISABLED"
		return
	if not aircraft.ai.engagement_ready():
		status = "WAITING FOR TAKEOFF"
		_clear_observation()
		return
	var target: FlightAircraft = aircraft.target
	if not CombatTeams.can_damage(aircraft.team_id, target):
		status = "FRIENDLY"
		return
	var offset: Vector3 = target.global_position - aircraft.global_position
	engagement_distance = offset.length()
	if engagement_distance < minimum_distance:
		_lose_sight(delta, "TOO CLOSE")
		return
	if not inside_arc(aircraft.global_basis.transposed() * offset):
		_lose_sight(delta, "OUTSIDE REAR ARC")
		return
	if not clear_line_of_sight(target.global_position):
		_lose_sight(delta, "BLOCKED")
		return
	_lost_seconds = 0
	var direction: Vector3 = offset.normalized()
	angular_motion = _previous_direction.angle_to(direction) / maxf(delta, 0.0001) if _previous_direction != Vector3.ZERO else 0
	_previous_direction = direction
	# Apparent silhouette size is visible information, not component targeting.
	var apparent_angle: float = rad_to_deg(2 * atan(maxf(target.collision_wing_span, 4) * 0.5 / maxf(engagement_distance, 1)))
	var bank: float = absf(asin(clampf(aircraft.global_basis.x.y, -1, 1)))
	visibility = clampf(apparent_angle / _profile.recognition_angle_degrees * (1 - bank / PI * 0.4), 0.08, 1)
	motion_penalty_degrees = _profile.bank_error_degrees * bank / (PI * 0.5) + _profile.manoeuvre_error_degrees * (aircraft.angular_velocity.length() + maxf(acceleration / 9.81 - 0.25, 0))
	error_degrees = _profile.tracking_error_degrees / sqrt(visibility) + _profile.angular_motion_error * angular_motion + motion_penalty_degrees
	_visible_seconds += delta * visibility
	_observe(target.global_position, direction, delta)
	if _perceived_time < 0 or observation_count < 2:
		status = "OBSERVING"
		return
	if _visible_seconds < _profile.reaction_seconds:
		status = "REACTING"
		return
	var duration: float = burst_duration * _profile.burst_duration_scale
	var cycle: float = maxf(duration + burst_rest * _profile.burst_rest_scale, 0.1)
	burst_clock += delta
	var index: int = floori(burst_clock / cycle)
	var in_burst: bool = fposmod(burst_clock, cycle) < duration
	if index != cycle_index:
		cycle_index = index
		_correct_between_bursts()
		_burst_position = perceived_position
		_burst_velocity = perceived_velocity
		_burst_time = _perceived_time
	_burst_active = in_burst
	aim_point = lead_point(target)
	if estimated_flight_time >= bullet_lifetime:
		status = "FLIGHT TIME TOO LONG"
		return
	var local_aim: Vector3 = aircraft.global_basis.transposed() * (aim_point - (aircraft.model as StukaModel).rear_mount.global_position)
	if not inside_arc(local_aim):
		status = "LEAD OUTSIDE ARC"
		return
	_update_wobble(delta)
	var desired_yaw: float = atan2(local_aim.x, local_aim.z) + deg_to_rad(aim_bias.x + _wobble.x)
	var desired_elevation: float = atan2(local_aim.y, Vector2(local_aim.x, local_aim.z).length()) + deg_to_rad(aim_bias.y + _wobble.y)
	var step: float = deg_to_rad(minf(tracking_rate_degrees, _profile.tracking_rate_degrees)) * aircraft.components.cockpit_factor() * delta
	yaw = move_toward(yaw, clampf(desired_yaw, -deg_to_rad(horizontal_arc_degrees), deg_to_rad(horizontal_arc_degrees)), step)
	elevation = move_toward(elevation, clampf(desired_elevation, deg_to_rad(minimum_elevation_degrees), deg_to_rad(maximum_elevation_degrees)), step)
	(aircraft.model as StukaModel).set_rear_gun_angles(yaw, elevation)
	# Alignment tests the gunner's perceived aim, never the true target direction.
	if absf(yaw - desired_yaw) > deg_to_rad(firing_alignment_degrees) or absf(elevation - desired_elevation) > deg_to_rad(firing_alignment_degrees):
		status = "TRACKING"
		return
	var gun_direction: Vector3 = -muzzle().global_basis.z
	if not shot_has_clearance(muzzle().global_position, gun_direction) or not clear_line_of_sight(muzzle().global_position + gun_direction * engagement_distance):
		status = "BLOCKED"
		return
	guns.rounds_per_second = rounds_per_second
	guns.bullet_speed = bullet_speed
	guns.bullet_damage = bullet_damage
	guns.bullet_lifetime = bullet_lifetime
	guns.spread_degrees = spread_degrees + motion_penalty_degrees * 0.25
	firing = in_burst
	guns.external_fire = firing
	status = "FIRING" if firing else "CORRECTING / COOLDOWN"

func _observe(position: Vector3, direction: Vector3, delta: float) -> void:
	_sample_clock -= delta
	if _sample_clock <= 0:
		_sample_clock += maxf(_profile.observation_interval, 0.02)
		var side: Vector3 = direction.cross(Vector3.UP).normalized()
		var up: Vector3 = side.cross(direction).normalized()
		var noise: float = tan(deg_to_rad(_profile.measurement_error_degrees)) * engagement_distance / sqrt(visibility)
		_sample_positions.append(position + (side * rng.randfn() + up * rng.randfn()) * noise)
		_sample_times.append(_clock)
	# Keep delayed observations even while firing, but do not apply fresh sight
	# corrections within a burst. The existing velocity estimate runs open-loop.
	while not _sample_times.is_empty() and _sample_times[0] <= _clock - _profile.observation_delay:
		var observed: Vector3 = _sample_positions.pop_front()
		var time: float = _sample_times.pop_front()
		if _burst_active:
			continue
		if _perceived_time >= 0:
			var measured: Vector3 = (observed - perceived_position) / maxf(time - _perceived_time, 0.01)
			perceived_velocity = perceived_velocity.lerp(measured.limit_length(180), _profile.velocity_learning)
		perceived_position = observed
		_perceived_time = time
		observation_count += 1

func _correct_between_bursts() -> void:
	var correction: float = _profile.burst_correction
	# Partial correction plus a correlated new judgement error. No feedback from
	# actual hit notifications, component HP, or the target's exact velocity.
	aim_bias = aim_bias * (1 - correction) + Vector2(rng.randfn(), rng.randfn()) * error_degrees * sqrt(correction * (2 - correction))
	_lead_bias = rng.randfn() * _profile.lead_error_fraction
	_range_bias = rng.randfn() * _profile.range_error_fraction
	_silhouette_bias = _silhouette_bias * (1 - correction) + Vector2(rng.randfn(), rng.randfn() * 0.25) * _profile.silhouette_aim_spread_metres * correction

func _update_wobble(delta: float) -> void:
	_wobble_clock -= delta
	if _wobble_clock <= 0:
		_wobble_clock += 0.12
		_wobble_goal = Vector2(rng.randfn(), rng.randfn()) * (_profile.vibration_degrees + motion_penalty_degrees)
	_wobble = _wobble.lerp(_wobble_goal, 1 - exp(-delta * 12))

func inside_arc(local_direction: Vector3) -> bool:
	if local_direction.z <= 0:
		return false
	var azimuth: float = rad_to_deg(atan2(local_direction.x, local_direction.z))
	var height: float = rad_to_deg(atan2(local_direction.y, Vector2(local_direction.x, local_direction.z).length()))
	return absf(azimuth) <= horizontal_arc_degrees and height >= minimum_elevation_degrees and height <= maximum_elevation_degrees

func lead_point(_target: FlightAircraft) -> Vector3:
	# Approximate mental lead from delayed observed positions, not a quadratic
	# exact-velocity intercept. Include inherited shooter velocity consistently.
	var position: Vector3 = _burst_position if _burst_active else perceived_position
	var velocity: Vector3 = _burst_velocity if _burst_active else perceived_velocity
	var time: float = _burst_time if _burst_active else _perceived_time
	position += velocity * maxf(_clock - time, 0)
	var offset: Vector3 = position - muzzle().global_position
	var direction: Vector3 = offset.normalized()
	var relative_velocity: Vector3 = velocity - aircraft.linear_velocity
	var perceived_range: float = offset.length() * clampf(1 + _range_bias, 0.5, 1.5)
	estimated_flight_time = perceived_range / maxf(bullet_speed - relative_velocity.dot(direction), bullet_speed * 0.4)
	var side: Vector3 = direction.cross(Vector3.UP).normalized()
	var up: Vector3 = side.cross(direction).normalized()
	return position + relative_velocity * estimated_flight_time * clampf(1 + _lead_bias, 0.5, 1.5) + side * _silhouette_bias.x + up * _silhouette_bias.y

func shot_has_clearance(origin: Vector3, direction: Vector3) -> bool:
	# Check EVERY dispersed round against own body + sensors. Foreign objects
	# are skipped only in this short own-airframe safety ray; full swept bullet
	# collision still hits terrain/targets normally. The origin is outside the body.
	var exclusions: Array[RID] = []
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * (aircraft.collision_wing_span + 8), aircraft.collision_layer | AircraftHitbox.LAYER)
	query.collide_with_areas = true
	query.hit_from_inside = true
	var space: PhysicsDirectSpaceState3D = aircraft.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(query)
	while not hit.is_empty():
		var collider: Object = hit.collider
		if collider == aircraft or (collider is AircraftHitbox and collider.damage_system.aircraft == aircraft):
			return false
		exclusions.append(hit.rid)
		query.exclude = exclusions
		hit = space.intersect_ray(query)
	return true

func clear_line_of_sight(point: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(muzzle().global_position, point, 15, [aircraft.get_rid()])
	query.collide_with_areas = true
	query.hit_from_inside = true
	var hit: Dictionary = aircraft.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Object = hit.collider
	return collider == aircraft.target or (collider is AircraftHitbox and collider.damage_system.aircraft == aircraft.target)
