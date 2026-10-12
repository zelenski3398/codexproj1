class_name InterceptionDefinition
extends Resource
@export var title: String = "Defend Valletta — Ta’ Qali Interception"
@export_multiline var briefing: String = "Take off from Ta’ Qali and follow the navigation checkpoints to the interception area. An Italian SM.79 bomber escorted by a Macchi C.200 is approaching Valletta. Destroy both aircraft before they reach their objective. You have five minutes from the moment the enemy formation appears."
@export var home_airfield: String = "ta_qali"
@export var checkpoint_positions: PackedVector3Array = PackedVector3Array()
@export var checkpoint_radius: float = 650
@export var formation_spawn_distance: float = 2500
@export_range(-90, 90, 1) var formation_bearing_degrees: float = 30
## Assign the supplied, radio-processed commander recording here when available.
@export var commander_voice: AudioStream
@export_range(-24, 6, 0.5) var commander_volume_db: float = 0
@export_range(-12, 0, 0.5) var radio_duck_db: float = -4
@export var detection_notice_seconds: float = 8
@export var minimum_checkpoint_agl: float = 80
# Ground target uses the existing Valletta landmark. Release is ~753 m up-course
# so bombs inheriting 65 m/s land there after falling from 700 m above sea level.
@export var target_area: Vector3 = Vector3(10131.404, 42.149, 3472.677)
@export var bombing_point: Vector3 = Vector3(10733.629, 700, 3021.008)
@export var deadline_seconds: float = 300
@export var arrival_radius: float = 70
@export_enum("c200", "cr42") var escort_type: String = "c200"
@export var escort_separation: float = 230
@export var spawn_clearance: float = 300
@export var bomb_count: int = 8
@export var bomb_interval: float = 0.7
