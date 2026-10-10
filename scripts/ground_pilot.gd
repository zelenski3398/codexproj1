class_name GroundPilot
extends CharacterBody3D
## Walking uses CharacterBody collision. Aircraft movement always uses forces.
@export var walking_speed: float = 5.0
var yaw: float = 0
var camera: Camera3D
var active: bool = true

func _ready() -> void:
	collision_layer = 16
	collision_mask = 7
	var collision: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	collision.shape = capsule
	add_child(collision)
	floor_snap_length = 0.45
	MeshKit.sphere(self, Vector3(0.42, 0.42, 0.42), Vector3(0, 0.65, 0), MeshKit.material(Color("c4ac88")))
	MeshKit.box(self, Vector3(0.55, 0.95, 0.35), Vector3(0, -0.05, 0), MeshKit.material(Color("516779")))
	camera = Camera3D.new()
	camera.fov = 65
	camera.far = 100000
	add_child(camera)
	camera.make_current()

func _physics_process(delta: float) -> void:
	if not active:
		return
	yaw += Input.get_axis("roll_right", "roll_left") * delta * 1.6
	var basis: Basis = Basis(Vector3.UP, yaw)
	var movement: Vector3 = basis * Vector3(-Input.get_axis("rudder_right", "rudder_left"), 0, -Input.get_axis("throttle_down", "throttle_up"))
	movement = movement.limit_length(1) * walking_speed
	velocity.x = movement.x
	velocity.z = movement.z
	velocity.y -= 9.81 * delta
	move_and_slide()
	var desired: Vector3 = global_position + basis * Vector3(0, 2.8, 5)
	var target: Vector3 = global_position + Vector3.UP * 0.6
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(target, desired, 7, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	camera.global_position = hit.position + hit.normal * 0.3 if not hit.is_empty() else desired
	camera.look_at(target)

func set_active(value: bool) -> void:
	active = value
	visible = value
	set_physics_process(value)
	collision_layer = 16 if value else 0
	collision_mask = 7 if value else 0
	if value:
		camera.make_current()
