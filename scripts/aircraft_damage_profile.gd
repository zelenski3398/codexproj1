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
