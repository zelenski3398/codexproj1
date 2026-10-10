class_name GunnerSkillProfile
extends Resource
## Human limitations, not changes to bullet damage, speed or a firing cutoff.
@export var skill_name: String = "Pilot"
@export_range(0, 3, 0.01) var reaction_seconds: float = 0.6
@export_range(0, 1, 0.01) var observation_delay: float = 0.22
@export_range(0.02, 1, 0.01) var observation_interval: float = 0.15
@export_range(0, 3, 0.01) var tracking_error_degrees: float = 0.38
@export_range(0, 1, 0.01) var measurement_error_degrees: float = 0.07
@export_range(0, 1, 0.01) var range_error_fraction: float = 0.12
@export_range(0, 1, 0.01) var lead_error_fraction: float = 0.14
@export_range(0.05, 1, 0.01) var velocity_learning: float = 0.35
@export_range(1, 90, 1) var tracking_rate_degrees: float = 42
@export_range(0, 1, 0.01) var burst_correction: float = 0.55
@export_range(0, 4, 0.05) var silhouette_aim_spread_metres: float = 1.2
@export_range(0.1, 4, 0.05) var recognition_angle_degrees: float = 0.85
@export_range(0, 5, 0.05) var angular_motion_error: float = 1.1 # degrees per rad/s
@export_range(0, 2, 0.01) var vibration_degrees: float = 0.08
@export_range(0, 2, 0.01) var bank_error_degrees: float = 0.20 # at 90 degrees bank
@export_range(0, 2, 0.01) var manoeuvre_error_degrees: float = 0.30 # per rad/s or excess g
@export_range(0, 3, 0.01) var reacquisition_seconds: float = 0.45
@export_range(0.1, 2, 0.05) var burst_duration_scale: float = 1
@export_range(0.1, 3, 0.05) var burst_rest_scale: float = 1
