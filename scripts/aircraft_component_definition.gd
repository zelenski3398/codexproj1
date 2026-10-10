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
