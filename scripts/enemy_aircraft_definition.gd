class_name EnemyAircraftDefinition
extends Resource
## Data only: a fresh EnemyAircraft owns each component's runtime state.
@export var id: String = "c200"
@export var title: String = "Macchi C.200 Saetta"
@export var marker: String = "C.200"
@export var model_script: Script
@export var damage: AircraftDamageProfile
@export var maximum_hp: float = 100
@export var mass_kg: float = 2600
@export var body_inertia: Vector3 = Vector3(8000, 13000, 7000)
@export var wingspan: float = 10.58
@export var body_size: Vector3 = Vector3(1.1, 1.2, 8.2)
@export var lower_wing_span: float = 0
@export var wing_chord: float = 2.1
@export var wing_area: float = 16.8
@export var thrust: float = 12500
@export var drag: float = 0.035
@export var cruise_speed: float = 75
@export var stall_speed: float = 31
@export var control_torque: Vector3 = Vector3(19000, 12500, 23000)
@export var maximum_bank: float = 50
@export var fixed_gear: bool = false
@export var bomber: bool = false
@export var gun_rate: float = 11
@export var bullet_speed: float = 765
@export var bullet_damage: float = 4
@export var bullet_lifetime: float = 1.5
@export var dispersion: float = 0.12
@export var defensive_rate: float = 10
@export var defensive_damage: float = 4

static func find(kind: String) -> EnemyAircraftDefinition:
	match kind:
		"cr42": return load("res://aircraft_definitions/cr42.tres")
		"c200": return load("res://aircraft_definitions/c200.tres")
		"c202": return load("res://aircraft_definitions/c202.tres")
		"sm79": return load("res://aircraft_definitions/sm79.tres")
	return null
