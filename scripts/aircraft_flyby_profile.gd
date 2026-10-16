class_name AircraftFlybyProfile
extends Resource
## Shared, read-only audio tuning. Runtime envelopes live on EnemyFlybyAudio.
@export_group("Enemy engine proximity")
@export_range(-40, 0, .5) var engine_volume_db: float = -7
@export var engine_audible_range: float = 4500
@export var engine_reference_distance: float = 120
@export_range(.1, 3, .05) var attenuation_exponent: float = 1.05
@export_range(.1, .95, .05) var far_fade_fraction: float = .75
@export var distance_blend_seconds: float = .14
@export_range(0, 1, .01) var distant_flight_mix: float = .28
@export var full_engine_range: float = 240
@export_range(0, 3, .05) var panning_strength: float = 1

@export_group("Bounded relative-motion Doppler")
@export var doppler_enabled: bool = true
@export var speed_of_sound: float = 343
@export_range(0, 1.5, .05) var doppler_strength: float = .9
@export var minimum_doppler_pitch: float = .72
@export var maximum_doppler_pitch: float = 1.45
@export var doppler_blend_seconds: float = .16
@export var maximum_radial_speed: float = 220
@export var listener_velocity_blend_seconds: float = .08
@export var listener_settle_seconds: float = .35
@export var listener_teleport_distance: float = 100
@export var maximum_listener_speed: float = 400

@export_group("Continuous close-pass airflow")
## Missing by default: supply a seamless MONO rushing-air loop, not a siren.
@export var airflow_stream: AudioStream
@export_range(-40, 0, .5) var airflow_volume_db: float = -9
@export var flyby_range: float = 260
@export var minimum_relative_speed: float = 30
@export var full_relative_speed: float = 110
@export_range(0, 3, .05) var airflow_intensity: float = 1
@export var airflow_attack_seconds: float = .12
@export var airflow_release_seconds: float = .75

@export_group("Shared enemy voice headroom")
## Linear conservative sum-of-peak budget, including both engine loops and air.
## Source-gain budgeting works with native streams AND web sample playback.
@export_range(.1, .75, .01) var enemy_peak_budget: float = .5
@export var mix_release_seconds: float = .4

func engine_attenuation(distance: float) -> float:
	var reference: float = maxf(engine_reference_distance, 1)
	var reach: float = maxf(engine_audible_range, reference + 1)
	var falloff: float = pow(reference / maxf(distance, reference), maxf(attenuation_exponent, .1))
	return falloff * (1 - smoothstep(reach * far_fade_fraction, reach, distance))

func airflow_amount(distance: float, relative_speed: float) -> float:
	var proximity: float = 1 - smoothstep(maxf(flyby_range, 1) * .15, maxf(flyby_range, 1), distance)
	var speed: float = smoothstep(minimum_relative_speed, maxf(full_relative_speed, minimum_relative_speed + 1), relative_speed)
	return proximity * speed * airflow_intensity
