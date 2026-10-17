class_name BomberPilot
extends EnemyPilot
## Level approach using the existing force-driven controller and its damage trim.
## Pace by remaining route distance/time; no transforms or velocities are set.
@export var bombing_altitude: float = 700
const DEFAULT_MINIMUM_SPEED: float = 48
const DEFAULT_MAXIMUM_SPEED: float = 80
@export var pace_minimum_speed: float = DEFAULT_MINIMUM_SPEED
@export var pace_maximum_speed: float = DEFAULT_MAXIMUM_SPEED
@export var speed_integral_gain: float = 0.007
var assigned_route: bool = false
var route_start: Vector3
var route_end: Vector3
var route_direction: Vector3 = Vector3.FORWARD
var route_duration: float = 300
var route_elapsed: float = 0
var speed_trim: float = 0
var arrived: bool = false
var arrival_elapsed: float = -1
@export var arrival_radius: float = 90

func assign_route(start: Vector3, end: Vector3, seconds: float) -> void:
	route_start = start
	route_end = end
	route_direction = ((end - start) * Vector3(1, 0, 1)).normalized()
	route_duration = seconds
	route_elapsed = 0
	speed_trim = 0
	arrived = false
	arrival_elapsed = -1
	assigned_route = true
	bombing_altitude = end.y
	evade_on_damage = false # bomber crew prioritises its assigned bombing course

func _physics_process(delta: float) -> void:
	if not aircraft.reset_pending and not aircraft.is_destroyed and not aircraft.is_crashed and _handle_damage(delta): return
	if aircraft.reset_pending:
		return
	if not assigned_route:
		# Configured bombers in ordinary encounters still fly a physical patrol.
		combat_enabled = false
		super._physics_process(delta)
		return
	if aircraft.is_destroyed:
		return
	route_elapsed += delta
	aircraft.pilot.fire = false
	aircraft.guns.use_assisted_aim = false
	mode = "PATROL"
	tactic = "LEVEL BOMBING" if arrived else "VALLETTA APPROACH"
	combat_unlocked = true
	var remaining: float = (route_end - aircraft.global_position).dot(route_direction)
	if not arrived and remaining <= arrival_radius and aircraft.global_position.distance_to(route_end) <= arrival_radius * 2:
		arrived = true
		arrival_elapsed = route_elapsed
	var wanted: float = clampf((remaining - arrival_radius * 0.5) / maxf(route_duration - route_elapsed, 1), pace_minimum_speed, pace_maximum_speed) if not arrived else 65
	cruise_speed = wanted
	var loitering: bool = arrived and route_elapsed > route_duration + 20
	var along: float = (aircraft.global_position - route_start).dot(route_direction)
	var aim: Vector3 = route_start + route_direction * (along + 2500)
	aim.y = bombing_altitude
	if loitering:
		patrol_center = route_end + route_direction * 1200
		patrol_radius = 1800
		aim = _patrol_point()
		tactic = "POST-RUN ORBIT"
	scan_clock -= delta
	if scan_clock <= 0:
		_scan_terrain()
		scan_clock = 0.15
	_fly_toward(avoidance_point if terrain_avoiding else aim, delta)
	# Slow bounded throttle trim cancels the base controller's airframe-specific
	# equilibrium error. It cannot overcome lost engines or badly damaged wings.
	var speed: float = aircraft.airspeed if loitering else aircraft.linear_velocity.dot(route_direction)
	speed_trim = clampf(speed_trim + (wanted - speed) * speed_integral_gain * delta, -0.4, 0.4)
	aircraft.pilot.throttle = clampf(aircraft.pilot.throttle + speed_trim, 0.05, 1)
