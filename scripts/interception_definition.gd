class_name InterceptionDefinition
extends Resource
@export var title: String = "Defend Valletta — Ta’ Qali Interception"
@export_multiline var briefing: String = "Take off from Ta’ Qali and follow two nearby airborne checkpoints. An Italian SM.79 bomber and Macchi C.200 escort appear at one o’clock, 1,200 metres away. Destroy both within three minutes. Results are confirmed when the timer expires; losing your aircraft fails immediately."
@export var home_airfield: String = "ta_qali"
@export var checkpoint_positions: PackedVector3Array = PackedVector3Array()
@export var checkpoint_radius: float = 350
@export var checkpoint_vertical_tolerance: float = 100
@export var formation_spawn_distance: float = 1200
@export var formation_height_offset: float = 60
@export var maximum_formation_height_difference: float = 150
@export_range(-90, 90, 1) var formation_bearing_degrees: float = 30
## Assign the supplied, radio-processed commander recording here when available.
@export var commander_voice: AudioStream
@export_range(-24, 6, 0.5) var commander_volume_db: float = 0
@export_range(-12, 0, 0.5) var radio_duck_db: float = -4
@export var detection_notice_seconds: float = 8
@export var minimum_checkpoint_agl: float = 80
# Geographic target remains unchanged. Automatic release lead accounts for the
# actual approach direction, speed and ballistic fall from the configured MSL.
@export var target_area: Vector3 = Vector3(10131.404, 42.149, 3472.677)
@export var bombing_point: Vector3 = Vector3(9600, 500, 3630)
@export var automatic_release_lead: bool = true
@export var deadline_seconds: float = 180
## Preserve the established physical approach, independent of the result deadline.
@export var approach_seconds: float = 90
@export var arrival_radius: float = 70
@export_enum("c200", "cr42") var escort_type: String = "c200"
@export var escort_separation: float = 230
@export var spawn_clearance: float = 300
@export var bomb_count: int = 8
@export var bomb_interval: float = 0.7
