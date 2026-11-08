class_name TutorialDefinition
extends Resource
## Coordinates use the existing Malta metre projection, north -Z.
@export var route: PackedVector3Array = PackedVector3Array([Vector3(3000,350,4750),Vector3(6500,450,4200),Vector3(9500,500,3700)])
@export var checkpoint_radius: float = 650
@export var minimum_flight_agl: float = 35
@export var landing_settle_seconds: float = 2
@export var emergency_setup_distance: float = 1800
@export var emergency_setup_height: float = 450
@export var emergency_capture_radius: float = 650
@export var damaged_hull_hp: float = 45
@export var wing_damage_fraction: float = .20
@export var elevator_damage_fraction: float = .15
@export var enemy_aim_error_degrees: float = 2.5
@export var enemy_burst_rest: float = 3
@export var enemy_grace_seconds: float = 15
