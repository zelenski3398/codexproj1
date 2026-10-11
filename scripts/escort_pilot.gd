class_name EscortPilot
extends EnemyPilot
## Ordinary fighter outside missions; formation escort/intercept within missions.
@export var threat_distance: float = 2200
@export var mission_leash: float = 3200
var escorted: EnemyAircraft
var mission_active: bool = false
var route_anchor: Vector3
var route_direction: Vector3 = Vector3.FORWARD
var route_speed: float = 65
var mission_elapsed: float = 0
var last_formation_position: Vector3 = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not mission_active:
		super._physics_process(delta)
		return
	if aircraft.reset_pending or aircraft.is_destroyed:
		return
	mission_elapsed += delta
	if is_instance_valid(escorted) and not escorted.is_destroyed:
		last_formation_position = escorted.global_position
	# A stopped bomber leaves a defence area, not a target marching forever
	# beyond Malta. The escort still engages through normal flight controls.
	var center: Vector3 = last_formation_position if last_formation_position != Vector3.ZERO else route_anchor
	center.y = route_anchor.y
	patrol_center = center
	var player_threat: bool = _player_airborne() and target.global_position.distance_to(center) < threat_distance
	var too_far: bool = aircraft.global_position.distance_to(center) > mission_leash
	if player_threat and not too_far:
		# The same pursuit, bounded lead, bursts, evasion and terrain checks.
		detection_range = threat_distance * 2
		grace_period = 0
		super._physics_process(delta)
	else:
		mode = "PATROL"
		tactic = "RETURN TO FORMATION" if too_far else "BOMBER ESCORT"
		tracking_target = false
		aircraft.pilot.fire = false
		aircraft.guns.use_assisted_aim = false
		var right: Vector3 = route_direction.cross(Vector3.UP)
		var aim: Vector3 = center + right * 230 + route_direction * 500 + Vector3.UP * 40
		cruise_speed = route_speed + clampf((aircraft.global_position.distance_to(center) - 260) * 0.015, -10, 12)
		scan_clock -= delta
		if scan_clock <= 0:
			_scan_terrain()
			scan_clock = 0.15
		_fly_toward(avoidance_point if terrain_avoiding else aim, delta)
