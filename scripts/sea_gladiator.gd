class_name SeaGladiator
extends FlightAircraft
## Smaller engine and greater biplane/gear drag produce lower performance
## through the shared forces, not by clamping speed or moving the transform.

func create_model() -> SpitfireModel:
	return SeaGladiatorModel.new()

func _ready() -> void:
	display_name = "Gloster Sea Gladiator"
	gun_description = "Four machine guns"
	takeoff_speed_hint = "115–135"
	approach_speed_hint = "115–135"
	safe_speed_hint = 110
	wing_area = 30.0
	engine_thrust = 8500.0
	lift_at_zero_alpha = 0.60
	parasite_drag = 0.044
	stall_speed = 24.0
	pitch_torque = 13000.0
	roll_torque = 14000.0
	rudder_torque = 10000.0
	collision_wing_span = 9.8
	super._ready()
	mass = 2200.0
	inertia = Vector3(7600, 11000, 6500)
	gear.retractable = false
	guns.name = "FourMachineGuns"
	# Four Brownings: two fuselage guns plus two beneath the lower wings.
	# All four use their visible ports, never the centre of the propeller.
	var upper_wing: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(9.8, 0.12, 1.45)
	upper_wing.shape = shape
	upper_wing.position = Vector3(0, 1.38, -0.55)
	add_child(upper_wing)
