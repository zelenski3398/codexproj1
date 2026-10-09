class_name LandingGear
extends Node
## Raycast springs stand in for three tyres. Forces, never transforms, support
## the rigid body. Flat terrain and bumps use the same collision queries.

@export var main_spring: float = 110000.0
@export var main_damping: float = 13000.0
@export var tail_spring: float = 55000.0
@export var tail_damping: float = 6500.0
@export var tyre_friction: float = 0.75
@export var fatal_sink_speed: float = 5.5
var extended: bool = true
var retractable: bool = true
var contact_count: int = 0
var compression: Array[float] = [0.0, 0.0, 0.0]
var last_notice: String = ""
var notice_time: float = 0.0
var anchors: Array[Vector3] = [Vector3(-1.25, -0.68, -1.05), Vector3(1.25, -0.68, -1.05), Vector3(0.0, -0.25, 3.75)]
var travel: Array[float] = [0.43, 0.43, 0.36]
var radii: Array[float] = [0.32, 0.32, 0.18]

func toggle() -> bool:
	notice_time = 3.0
	if not retractable:
		last_notice = "FIXED LANDING GEAR · cannot retract"
		return false
	if extended and contact_count > 0:
		last_notice = "GEAR LOCKED · weight on wheels"
		return false
	extended = not extended
	last_notice = "GEAR DOWN" if extended else "GEAR UP"
	return true

func _process(delta: float) -> void:
	notice_time = maxf(notice_time - delta, 0.0)
	if notice_time == 0.0:
		last_notice = ""

func integrate(state: PhysicsDirectBodyState3D, aircraft: RigidBody3D, brakes: bool) -> float:
	contact_count = 0
	var worst_sink: float = 0.0
	var basis := state.transform.basis
	var space := aircraft.get_world_3d().direct_space_state
	for i in range(3):
		compression[i] = 0.0
		if not extended:
			continue
		var offset := basis * anchors[i]
		var origin := state.transform.origin + offset
		var reach := travel[i] + radii[i]
		var query := PhysicsRayQueryParameters3D.create(origin + basis.y * 0.08, origin - basis.y * reach, 1, [aircraft.get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var distance: float = origin.distance_to(hit.position)
		var amount := clampf(reach - distance, 0.0, travel[i])
		if amount <= 0.0:
			continue
		compression[i] = amount
		contact_count += 1
		var normal: Vector3 = hit.normal
		var point_velocity := state.linear_velocity + state.angular_velocity.cross(offset)
		var sink := point_velocity.dot(normal)
		worst_sink = minf(worst_sink, sink)
		var spring := main_spring if i < 2 else tail_spring
		var damper := main_damping if i < 2 else tail_damping
		var load := clampf(amount * spring - sink * damper, 0.0, 85000.0)
		state.apply_force(normal * load, offset)
		var right := basis.x.slide(normal).normalized()
		var forward := (-basis.z).slide(normal).normalized()
		var sideways := state.linear_velocity.dot(right)
		var rolling := state.linear_velocity.dot(forward)
		var friction := load * tyre_friction
		var lateral_force := clampf(-sideways * 10000.0, -friction, friction)
		var brake_force := clampf(-rolling * (2600.0 if brakes else 7.0), -friction, friction)
		# Apply tyre friction centrally to forgive taildragger nose-over under
		# braking. Suspension still applies at the real wheel attachment points.
		state.apply_central_force(right * lateral_force + forward * brake_force)
	return worst_sink
