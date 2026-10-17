class_name AircraftComponentDefinition
extends Resource
## Configuration only. Runtime integrity belongs to each AircraftDamage instance.
@export var id: StringName = &"fuselage"
@export var display_name: String = "Fuselage"
@export_range(1, 1000, 1) var max_integrity: float = 100.0
@export_range(0, 10, 0.05) var damage_multiplier: float = 1.0
@export_range(0, 10, 0.05) var airframe_multiplier: float = 1.0
@export var debug_color: Color = Color.CYAN
@export var hitboxes: Array[DamageHitboxSpec] = []
@export_group("Role, state and connections")
@export_enum("structure", "wing", "engine", "fuel", "control", "gear", "crew", "payload") var role: String = "structure"
@export var adjacent: Array[StringName] = []
@export var state_thresholds: Vector3 = Vector3(0.75, 0.50, 0.25)
@export var combustible: bool = false
@export var detachable: bool = false
@export var fragment_region: StringName = &""
@export var material_kind: String = "metal"
@export var propeller_index: int = 0
@export var thrust_weight: float = 1.0
@export var tank_capacity: float = 1.0
@export var structural_limit_g: float = 6.0
@export var structural_speed: float = 150.0
@export var minimum_failure_ratio: float = 0.30
@export var jam_threshold: float = 0.08
