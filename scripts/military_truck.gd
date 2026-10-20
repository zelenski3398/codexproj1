class_name MilitaryTruck
extends CharacterBody3D
## Forgiving kinematic vehicle, using swept CharacterBody collisions and gravity.
## No rigid chassis tipping: pitch/roll only affect the visual model on slopes.
@export var forward_speed: float = 12
@export var reverse_speed: float = 4
@export var acceleration: float = 4
@export var braking: float = 16
@export var wheelbase: float = 2.78
var occupied: bool = false
var speed: float = 0
var steering: float = 0
var model: MilitaryTruckModel
var camera: Camera3D
var grounded: bool = false
func _ready() -> void:
	add_to_group("airfield_trucks")
	collision_layer = 1
	collision_mask = 23 # Terrain/buildings/guns, both aircraft teams, walking pilot.
	floor_snap_length = 0.8
	floor_max_angle = deg_to_rad(32)
	floor_constant_speed = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9,2.25,4.6)
	collision.shape = shape
	collision.position.y = 1.125
	add_child(collision)
	model = MilitaryTruckModel.new()
	add_child(model)
	camera = Camera3D.new()
	camera.name = "DrivingCamera"
	camera.fov = 65
	camera.far = 100000
	add_child(camera)
	var label := Label3D.new()
	label.text = "MILITARY TRUCK · E TO ENTER"
	label.position.y = 3.2
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 25
	label.pixel_size = .025
	label.visibility_range_end = 100
	add_child(label)

func _physics_process(delta: float) -> void:
	if not occupied and grounded and absf(speed)<.1:
		# Parking brake holds a settled unoccupied chassis on the apron grade.
		velocity=Vector3.ZERO
		steering=0
		return
	var drive: float = Input.get_axis("throttle_down","throttle_up") if occupied else 0
	var desired: float = drive * (forward_speed if drive >= 0 else reverse_speed)
	var brake: bool = not occupied or Input.is_action_pressed("brake")
	speed = move_toward(speed,0 if brake else desired,(braking if brake or is_zero_approx(drive) else acceleration)*delta)
	steering = move_toward(steering,Input.get_axis("rudder_left","rudder_right") if occupied else 0,delta*3)
	rotation.y -= steering*clampf(speed/wheelbase*.5,-1,1)*delta
	var forward: Vector3 = -global_basis.z
	velocity.x = forward.x*speed
	velocity.z = forward.z*speed
	velocity.y -= 9.81*delta
	move_and_slide()
	grounded = is_on_floor()
	# Stop drivetrain accumulation against solid obstacles, rather than push
	# the collision body through an aircraft, wall or emplacement.
	if get_real_velocity().length() < absf(speed)*.25 and is_on_wall(): speed = 0
	model.animate(speed,steering,delta)
	if occupied: update_camera(delta)

func update_camera(delta: float) -> void:
	var target := global_position + Vector3.UP*1.4
	var desired := global_position + global_basis*Vector3(0,4.4,8)
	var ray := PhysicsRayQueryParameters3D.create(target,desired,7,[get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty(): desired = hit.position + hit.normal*.3
	camera.global_position = camera.global_position.lerp(desired,1-exp(-delta*8))
	camera.look_at(target)

func start_driving() -> void:
	occupied = true
	model.driver.visible = true
	camera.global_position = global_position + global_basis*Vector3(0,4.4,8)
	camera.make_current()

func stop_driving() -> void:
	occupied = false
	speed = 0
	velocity = Vector3.ZERO
	model.driver.visible = false
	steering = 0

func get_team_id() -> int: return CombatTeams.PLAYER
