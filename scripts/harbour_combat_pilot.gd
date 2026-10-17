class_name HarbourCombatPilot
extends EnemyPilot
## Reusable formation/escort/withdrawal orders, all through existing pilot inputs.
var leader: FlightAircraft
var formation_offset: Vector3 = Vector3(0, 35, 180)
var withdrawing: bool = false
var withdrawal_goal: Vector3
var takeoff_hold: bool = false
var takeoff_delay: float = 0
var age: float = 0
var departed: bool = false
var takeoff_direction: Vector3 = Vector3.FORWARD

func _physics_process(delta: float) -> void:
	if not aircraft.reset_pending and not aircraft.is_destroyed and not aircraft.is_crashed and _handle_damage(delta): return
	age += delta
	if aircraft.reset_pending or aircraft.is_destroyed or aircraft.is_crashed: return
	if not departed and aircraft.gear.contact_count == 0 and aircraft.altitude > 25: departed = true
	if takeoff_hold and not departed:
		aircraft.pilot.reset_commands()
		aircraft.pilot.brakes = true
		return
	if not departed:
		takeoff_delay = maxf(0, takeoff_delay - delta)
		aircraft.pilot.brakes = takeoff_delay > 0
		aircraft.pilot.throttle = 0 if takeoff_delay > 0 else 1
		var forward: Vector3 = -aircraft.global_basis.z
		var error: float = wrapf(atan2(-takeoff_direction.x, -takeoff_direction.z) - atan2(-forward.x, -forward.z), -PI, PI)
		aircraft.pilot.pitch = clampf((.12 - asin(clampf(forward.y,-1,1))) * 4, -.5, .5) if aircraft.airspeed > 31 else 0
		aircraft.pilot.roll = clampf(-aircraft.global_basis.x.y * 3, -.5, .5)
		aircraft.pilot.rudder = clampf(error * .8, -.5, .5)
		aircraft.pilot.fire = false
		tactic = "TAKEOFF" if takeoff_delay == 0 else "WAIT FOR RUNWAY"
		return
	if not withdrawing and is_instance_valid(target) and not target.is_destroyed and not target.is_crashed:
		super._physics_process(delta)
		return
	aircraft.pilot.fire = false
	aircraft.guns.use_assisted_aim = false
	mode = "PATROL"
	tactic = "WITHDRAW" if withdrawing else "FORM UP / REJOIN"
	var aim: Vector3 = withdrawal_goal
	if not withdrawing and is_instance_valid(leader):
		aim = leader.global_position + leader.global_basis * formation_offset
		aim.y = maxf(aim.y, leader.global_position.y + 25)
		cruise_speed = clampf(leader.airspeed + (aircraft.global_position.distance_to(aim) - 100) * .018, 38, 65)
	scan_clock -= delta
	if scan_clock <= 0:
		_scan_terrain()
		scan_clock = .15
	# Same-team collision avoidance steers away through control inputs.
	for other in get_tree().get_nodes_in_group("combat_aircraft"):
		if other == aircraft or other.is_destroyed or other.team_id != aircraft.team_id: continue
		var offset: Vector3 = aircraft.global_position - other.global_position
		if offset.length_squared() < 90 * 90:
			aim = aircraft.global_position + offset.normalized() * 250 - aircraft.global_basis.z * 160 + Vector3.UP * 45
			break
	_fly_toward(avoidance_point if terrain_avoiding else aim, delta)

func _pursuit_point() -> Vector3:
	var aim: Vector3 = super._pursuit_point()
	for other in get_tree().get_nodes_in_group("combat_aircraft"):
		if other == aircraft or other.is_destroyed or other.team_id != aircraft.team_id: continue
		var offset: Vector3 = aircraft.global_position - other.global_position
		var predicted: Vector3 = offset + (aircraft.linear_velocity - other.linear_velocity) * 1.5
		if offset.length() < 85 or predicted.length() < 65:
			var away: Vector3 = offset.normalized() if offset.length() > 1 else aircraft.global_basis.x
			return aircraft.global_position + away * 260 - aircraft.global_basis.z * 220 + Vector3.UP * 35
	return aim
