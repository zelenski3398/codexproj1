class_name AircraftImpactProfile
extends Resource
## Replace these clearly labelled synthesized placeholders with recordings.
@export_group("Assets")
@export var metal_hits: Array[AudioStream] = []
@export var heavy_hit: AudioStream
@export var water_impact: AudioStream
@export var explosion: AudioStream
@export_group("Hit mix")
@export var own_hit_db: float = -2
@export var other_hit_db: float = -12
@export var hit_range: float = 180
@export var own_hit_range: float = 120
@export var hit_unit_size: float = 10
@export var hit_attenuation: float = 1.35
@export var hit_interval: float = 0.045
@export var pitch_variation: float = 0.12
@export var volume_variation_db: float = 2
@export_group("Water and explosion")
@export var water_db: float = -9
@export var water_range: float = 2200
@export var explosion_db: float = -8
@export var explosion_range: float = 2200
@export var water_effect_minimum: float = 0.35
@export var water_effect_maximum: float = 2.3
@export var full_water_impact_speed: float = 100
@export var water_hull_clearance: float = 0.6
@export var explosion_strength: float = 1.8
@export_group("Budgets")
@export var cluster_headroom_db: float = 3.0
@export_range(4,24,1) var audio_voices: int = 12
@export_range(4,32,1) var maximum_effects: int = 24
@export_group("Optional component event recordings (silent when unassigned)")
@export var event_sounds: Dictionary[StringName, AudioStream] = {}
@export_group("Global aircraft particle reservations")
@export var maximum_smoke_particles: int = 512
@export var maximum_flame_particles: int = 192
