class_name HarbourDefinition
extends Resource
## Fictional encounter authored for the existing Sea Gladiator forces/ballistics.
@export var title: String = "Faith, Hope and Charity — Harbour Interception"
@export_multiline var briefing: String = "Fly Faith from Ħal Far with Hope and Charity. Stop three Italian bomber formations before they release on Fort St Elmo or Fort St Angelo. Wave 1: bomber + 3 escorts. Wave 2: bomber + 3 escorts. Wave 3: bomber + 2 aces. Wingmen losses persist."
@export var fort_max_hp: float = 1000
@export var takeoff_activation_agl: float = 65
@export var takeoff_activation_seconds: float = 6
@export var incoming_distance: float = 2100
@export var minimum_player_separation: float = 1000
@export var approach_height: float = 420
@export var bomber_speed: float = 49
@export var escort_separation: float = 180
@export var regroup_seconds: float = 12
@export var attack_warning_seconds: float = 24
@export var payload_count: int = 4
@export var payload_interval: float = 0.6
@export var bomb_damage: float = 520
@export var bomb_blast_radius: float = 90
@export var escort_engagement_seconds: float = 110
@export var withdrawal_distance: float = 5500
@export var withdrawal_timeout: float = 110
@export var bomber_watchdog_seconds: float = 300
@export var ace_aim_scale: float = 0.20
@export var ace_dispersion_scale: float = 0.25
@export var intro_voice: AudioStream
@export var success_voice: AudioStream
## Optional recordings for every other cue. Unassigned entries use subtitles.
@export var cue_voices: Dictionary[String, AudioStream] = {}
@export var voice_volume_db: float = 0
@export var radio_duck_db: float = -4
