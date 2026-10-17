class_name AircraftDamageProfile
extends Resource
## Shared data resources may be edited in the Inspector; no runtime state here.
@export var components: Array[AircraftComponentDefinition] = []
@export_group("Flight effects at zero component integrity")
@export_range(0, 1, 0.01) var wing_lift_loss: float = 0.65
@export_range(0, 1, 0.001) var wing_drag_gain: float = 0.04
@export_range(0, 1, 0.001) var fuselage_drag_gain: float = 0.035
@export var lift_lever_arm: float = 2.3
@export_range(0, 2, 0.01) var asymmetric_drag_gain: float = 1.0
@export_range(0.1, 4, 0.05) var engine_power_exponent: float = 1.3
@export_range(0, 1, 0.01) var minimum_rudder_authority: float = 0.1
@export_range(0, 1, 0.01) var minimum_elevator_authority: float = 0.1
@export_range(0, 1, 0.01) var minimum_cockpit_authority: float = 0.45
@export_group("Fuel hazards per accepted tank hit")
@export_range(0, 1, 0.01) var fuel_leak_probability: float = 0.4
@export_range(0, 1, 0.01) var fuel_fire_probability: float = 0.12
@export var fuel_random_seed: int = 1944
@export_range(0, 1, 0.001) var fuel_leak_rate: float = 0.02 # full tank fraction / s, scaled by damage
@export_range(0, 1, 0.001) var fuel_burn_rate: float = 0.03
@export_range(0, 100, 0.1) var fuel_fire_damage_per_second: float = 2.0
@export_range(0, 100, 0.1) var fuel_component_burn_per_second: float = 4.0
@export_group("Progressive failures")
@export var damage_seed: int = 1944
@export var fire_step_seconds: float = 0.5
@export var fire_damage_per_second: float = 4.0
@export var fire_spread_probability_per_second: float = 0.12
@export var tank_ignition_probability: float = 0.08
@export var structural_failure_probability: float = 0.35
@export var structural_check_seconds: float = 0.25
@export var structural_fatigue_rate: float = 0.12
@export var low_fuel_pressure_threshold: float = 0.01
@export var engine_asymmetry_lever: float = 1.0
@export var failed_propeller_drag: float = 0.008
@export var gear_collapse_ratio: float = 0.20
@export_group("Crash energy normalized against 3000 kg at 30 m/s")
@export var horizontal_impact_fraction: float = 0.018
@export var controlled_crash_limit: float = 0.18
@export var moderate_crash_limit: float = 0.9
@export var severe_crash_limit: float = 3.0
@export var fuel_impact_ignition_probability: float = 0.4
@export_group("Debris and effects")
@export var maximum_debris: int = 64
@export var maximum_colliding_debris: int = 32
@export var maximum_detailed_debris: int = 32
@export var detailed_debris_distance: float = 1800
@export var minor_debris_lifetime: float = 8
@export var major_debris_lifetime: float = 22
@export var maximum_damage_marks: int = 24
@export var maximum_smoke_emitters: int = 6
@export var maximum_fire_emitters: int = 4
@export_group("Critical engine reliability")
@export var engine_heat_rate: float = 0.12
@export var engine_cooling_rate: float = 0.06
@export var engine_seizure_temperature: float = 1.0
