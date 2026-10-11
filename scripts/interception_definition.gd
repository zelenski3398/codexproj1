class_name InterceptionDefinition
extends Resource
@export var title: String = "Defend Valletta — Ta’ Qali Interception"
@export_multiline var briefing: String = "Take off from Ta’ Qali and reach the interception checkpoint. An Italian SM.79 bomber escorted by a Macchi C.200 is approaching Valletta. Destroy both aircraft before they reach their objective. You have five minutes from the moment the enemy formation appears."
@export var home_airfield: String = "ta_qali"
@export var checkpoint: Vector3 = Vector3(3957.155, 450, 3357.118)
@export var checkpoint_radius: float = 500
@export var minimum_checkpoint_agl: float = 80
# Ground target uses the existing Valletta landmark. Release is ~753 m up-course
# so bombs inheriting 65 m/s land there after falling from 700 m above sea level.
@export var target_area: Vector3 = Vector3(10131.404, 42.149, 3472.677)
@export var bombing_point: Vector3 = Vector3(10733.629, 700, 3021.008)
@export var approach_direction: Vector3 = Vector3(-0.8, 0, 0.6)
@export var approach_speed: float = 65
@export var deadline_seconds: float = 300
@export var arrival_radius: float = 70
@export_enum("c200", "cr42") var escort_type: String = "c200"
@export var escort_separation: float = 230
@export var spawn_clearance: float = 300
@export var bomb_count: int = 8
@export var bomb_interval: float = 0.7
