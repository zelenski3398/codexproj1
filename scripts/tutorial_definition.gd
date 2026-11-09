class_name TutorialDefinition
extends Resource
## Coordinates use the existing Malta metre projection, north -Z.
@export var route: PackedVector3Array = PackedVector3Array([Vector3(3000,350,4750),Vector3(6500,450,4200),Vector3(9500,500,3700)])
@export var checkpoint_radius: float = 650
@export var minimum_flight_agl: float = 35
@export var landing_settle_seconds: float = 2
@export_group("Gladiator return and short walk to Spitfire")
@export var landing_sector_length: float = 240
@export var landing_sector_width: float = 46
@export var landing_rollout_lead: float = 250
@export var handover_apron_x: float = 61
@export var handover_parking_radius: float = 8
@export var handover_maximum_walk: float = 45
@export var handover_maximum_speed: float = 1.5
@export var handover_minimum_taxi_power: float = .15
@export_group("Emergency exercise")
@export var emergency_setup_distance: float = 1800
@export var emergency_setup_height: float = 450
@export var emergency_capture_radius: float = 650
@export var damaged_hull_hp: float = 45
@export var wing_damage_fraction: float = .20
@export var elevator_damage_fraction: float = .15
@export var enemy_aim_error_degrees: float = 2.5
@export var enemy_burst_rest: float = 3
@export var enemy_grace_seconds: float = 15
