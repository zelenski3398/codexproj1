class_name RearGunner
extends Node
## A flexible rear-cockpit mount, not an all-direction turret. Only the gun
## rotates directly; the aircraft keeps using its normal rigid-body controls.
@export_group("Defensive engagement (prototype tuning)")
@export var enabled: bool = true
@export var engagement_range: float = 500.0 # Practical GAME cutoff, not a verified historical limit.
@export var minimum_distance: float = 18.0
@export var horizontal_arc_degrees: float = 70.0 # each side of local +Z (astern)
@export var minimum_elevation_degrees: float = -12.0
@export var maximum_elevation_degrees: float = 60.0
@export var tracking_rate_degrees: float = 75.0
@export var firing_alignment_degrees: float = 1.5
@export var burst_duration: float = 0.45
@export var burst_rest: float = 1.4
@export var aim_error_degrees: float = 0.22
@export var aim_seed: int = 1943
@export_group("MG 15-style weapon (approximate)")
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

func _ready() -> void:
	guns = WingGuns.new()
	guns.name = "RearMG15"
	guns.aircraft = aircraft
	guns.externally_controlled = true
	guns.forward_from_port = true
	guns.firing_ports = [(aircraft.model as StukaModel).rear_muzzle]
	guns.convergence_distance = 0
	guns.pool_capacity = 128
	add_child(guns)
	guns.pool.tracer_material.albedo_color = Color("ff8050")
	reset()

func reset() -> void:
	burst_clock = 0
	cycle_index = -1
	aim_bias = Vector2.ZERO
	rng.seed = aim_seed
	yaw = 0
	elevation = deg_to_rad(12)
	firing = false
	status = "WAITING FOR TAKEOFF"
	(aircraft.model as StukaModel).set_rear_gun_angles(yaw, elevation)
	guns.reset()

func cease_fire() -> void:
	firing = false
	guns.external_fire = false

func muzzle() -> Marker3D:
	return (aircraft.model as StukaModel).rear_muzzle

func _physics_process(delta: float) -> void:
	cease_fire()
	if not enabled or aircraft.is_destroyed or aircraft.is_crashed or aircraft.reset_pending:
		status = "OFFLINE"
		return
	if aircraft.components.integrity_ratio(&"cockpit") <= 0:
		status = "CREW DISABLED"
		return
	if not aircraft.ai.engagement_ready():
		status = "WAITING FOR TAKEOFF"
		return
	var target: FlightAircraft = aircraft.target
	if not CombatTeams.can_damage(aircraft.team_id, target):
		status = "FRIENDLY"
		return
	var distance: float = aircraft.global_position.distance_to(target.global_position)
	if distance > engagement_range or distance < minimum_distance:
		status = "OUT OF RANGE"
		return
	var direction: Vector3 = aircraft.global_basis.transposed() * (target.global_position - aircraft.global_position)
	if not inside_arc(direction):
		status = "OUTSIDE REAR ARC"
		return
	burst_clock += delta
	var cycle: float = maxf(burst_duration + burst_rest, 0.1)
	var index: int = floori(burst_clock / cycle)
	if index != cycle_index:
		cycle_index = index
		aim_bias = Vector2(rng.randf_range(-aim_error_degrees, aim_error_degrees), rng.randf_range(-aim_error_degrees, aim_error_degrees))
	aim_point = lead_point(target)
	var local_aim: Vector3 = aircraft.global_basis.transposed() * (aim_point - (aircraft.model as StukaModel).rear_mount.global_position)
	var desired_yaw: float = atan2(local_aim.x, local_aim.z) + deg_to_rad(aim_bias.x)
	var desired_elevation: float = atan2(local_aim.y, Vector2(local_aim.x, local_aim.z).length()) + deg_to_rad(aim_bias.y)
	if not inside_arc(local_aim):
		status = "LEAD OUTSIDE ARC"
		return
	# Damage uses the shared cockpit impairment; it cannot grant extra traverse.
	var step: float = deg_to_rad(tracking_rate_degrees) * aircraft.components.cockpit_factor() * delta
	yaw = move_toward(yaw, clampf(desired_yaw, -deg_to_rad(horizontal_arc_degrees), deg_to_rad(horizontal_arc_degrees)), step)
	elevation = move_toward(elevation, clampf(desired_elevation, deg_to_rad(minimum_elevation_degrees), deg_to_rad(maximum_elevation_degrees)), step)
	(aircraft.model as StukaModel).set_rear_gun_angles(yaw, elevation)
	var gun_direction: Vector3 = -muzzle().global_basis.z
	var aim_direction: Vector3 = (aim_point - muzzle().global_position).normalized()
	if gun_direction.angle_to(aim_direction) > deg_to_rad(firing_alignment_degrees):
		status = "TRACKING"
		return
	if not clear_line_of_sight(aim_point) or not clear_line_of_sight(target.global_position) or not clear_line_of_sight(muzzle().global_position + gun_direction * distance):
		status = "BLOCKED"
		return
	guns.rounds_per_second = rounds_per_second
	guns.bullet_speed = bullet_speed
	guns.bullet_damage = bullet_damage
	guns.bullet_lifetime = bullet_lifetime
	guns.spread_degrees = spread_degrees
	firing = fposmod(burst_clock, cycle) < burst_duration
	guns.external_fire = firing
	status = "FIRING" if firing else "COOLDOWN"

func inside_arc(local_direction: Vector3) -> bool:
	if local_direction.z <= 0:
		return false
	var azimuth: float = rad_to_deg(atan2(local_direction.x, local_direction.z))
	var height: float = rad_to_deg(atan2(local_direction.y, Vector2(local_direction.x, local_direction.z).length()))
	return absf(azimuth) <= horizontal_arc_degrees and height >= minimum_elevation_degrees and height <= maximum_elevation_degrees

func lead_point(target: FlightAircraft) -> Vector3:
	var offset: Vector3 = target.global_position - muzzle().global_position
	var relative_velocity: Vector3 = target.linear_velocity - aircraft.linear_velocity
	var a: float = relative_velocity.length_squared() - bullet_speed * bullet_speed
	var b: float = 2 * offset.dot(relative_velocity)
	var time: float = offset.length() / maxf(bullet_speed, 1)
	var discriminant: float = b * b - 4 * a * offset.length_squared()
	if absf(a) > 0.001 and discriminant >= 0:
		var t0: float = (-b - sqrt(discriminant)) / (2 * a)
		var t1: float = (-b + sqrt(discriminant)) / (2 * a)
		if t0 > 0 and t1 > 0:
			time = minf(t0, t1)
		elif maxf(t0, t1) > 0:
			time = maxf(t0, t1)
	return target.global_position + relative_velocity * clampf(time, 0, bullet_lifetime)

func clear_line_of_sight(point: Vector3) -> bool:
	# Keep OWN component areas in this ray: the tail/fin really obstructs the
	# gun. Bullets still exclude owner areas, so safety must be checked here.
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(muzzle().global_position, point, 15, [aircraft.get_rid()])
	query.collide_with_areas = true
	query.hit_from_inside = true
	var hit: Dictionary = aircraft.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Object = hit.collider
	return collider == aircraft.target or (collider is AircraftHitbox and collider.damage_system.aircraft == aircraft.target)
