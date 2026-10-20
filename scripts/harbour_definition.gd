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
@export_group("Normal escorts only")
@export var normal_aim_error_scale: float = 4.0
@export var normal_dispersion_scale: float = 1.6
@export var normal_burst_seconds: float = .5
@export var normal_burst_rest: float = 2.0
@export var normal_reaction_seconds: float = 3.0
@export_enum("Cadet", "Pilot", "Ace") var normal_bomber_gunner_skill: int = 0
@export var intro_voice: AudioStream
@export var success_voice: AudioStream
## Optional recordings for every other cue. Unassigned entries use subtitles.
@export var cue_voices: Dictionary[String, AudioStream] = {}
@export var voice_volume_db: float = 0
@export var radio_duck_db: float = -4

@export_group("Wingman radio")
@export var faith_status_voice: AudioStream
@export var hope_status_ack: AudioStream
@export var charity_status_ack: AudioStream
## Short identity/condition recordings only: sound / minor / significant /
## critical / engine_damage / controls_damage / fuel_empty / fuel_leak / fire.
## Do not record fixed bearings or enemy counts in these condition slots.
@export var hope_status_variants: Dictionary[String, AudioStream] = {}
@export var charity_status_variants: Dictionary[String, AudioStream] = {}
@export_range(-24, 6, .5) var wingman_radio_volume_db: float = 0
@export var radio_subtitle_seconds: float = 9
@export var radio_request_cooldown: float = 20
@export var radio_reply_gap: float = .45
@export var radio_spotting_distance: float = 3000
@export_range(30, 360, 1) var radio_spotting_fov: float = 220
@export var radio_spotting_interval: float = .35
@export var radio_memory_seconds: float = 15
