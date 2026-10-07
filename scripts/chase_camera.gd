class_name ChaseCamera
extends Camera3D
@export var follow_distance: float = 19.0
@export var follow_height: float = 6.0
@export var smoothing: float = 5.0
var aircraft: FlightAircraft
var initialized: bool = false

func _ready() -> void:
	fov = 65.0
	near = 0.15
	far = 14000.0
	current = true

func snap() -> void:
	initialized = false

func _physics_process(delta: float) -> void:
	if not is_instance_valid(aircraft):
		return
	# Keep horizon level; yaw follows the fuselage, with a little velocity lead.
	var back := aircraft.global_basis.z
	var desired := aircraft.global_position + back * follow_distance + Vector3.UP * follow_height
	var target := aircraft.global_position + Vector3.UP * 1.0
	# Velocity feed-forward compensates smoothing lag, keeping the aircraft
	# large enough on screen at high speed without snapping the camera.
	if initialized:
		desired += aircraft.linear_velocity / maxf(smoothing, 0.1)
	var next := global_position.lerp(desired, 1.0 - exp(-smoothing * delta)) if initialized else desired
	# Check the actual interpolated segment, not just the ideal destination.
	var query := PhysicsRayQueryParameters3D.create(target, next, 1, [aircraft.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		next = hit.position + hit.normal * 1.0
	# Also clear the terrain under the interpolated camera position.
	var down := PhysicsRayQueryParameters3D.create(next + Vector3.UP * 200.0, next + Vector3.DOWN * 500.0, 1, [aircraft.get_rid()])
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(down)
	if not floor_hit.is_empty():
		next.y = maxf(next.y, floor_hit.position.y + 1.5)
	global_position = next
	var look_target := target + aircraft.linear_velocity * 0.05
	if global_position.distance_to(look_target) > 0.1:
		look_at(look_target, Vector3.UP)
	initialized = true
