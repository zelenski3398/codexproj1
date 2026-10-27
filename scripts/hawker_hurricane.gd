class_name HawkerHurricane
extends FlightAircraft
## Mk I gameplay configuration lives in aircraft/hurricane_mk_i.tscn.
@export var loaded_mass: float = 2994
@export var body_inertia: Vector3 = Vector3(10800,16500,9800)
@export var gun_rate: float = 12
@export var gun_damage: float = 4
@export var gun_velocity: float = 850
@export var gun_convergence: float = 250
func create_model() -> SpitfireModel:
	return HurricaneModel.new()
func default_damage_profile() -> AircraftDamageProfile:
	return preload("res://damage_profiles/hurricane_mk_i.tres")
func _ready() -> void:
	super._ready()
	mass=loaded_mass;inertia=body_inertia
	for node in get_children():
		if node is CollisionShape3D and node.shape is CapsuleShape3D:
			node.shape.height=9.2;node.shape.radius=.5;node.position.z=.35
	gear.anchors=[Vector3(-1.55,-.68,-1.05),Vector3(1.55,-.68,-1.05),Vector3(0,-.25,4.65)]
	guns.rounds_per_second=gun_rate;guns.bullet_damage=gun_damage
	guns.bullet_speed=gun_velocity;guns.convergence_distance=gun_convergence
	if seated_pilot!=null:seated_pilot.position=Vector3(0,-.78,.45)
