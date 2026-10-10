class_name AircraftHealth
extends Node
## Reusable health component. A destroyed life stays latched until reset;
## healing can stop effects but cannot resurrect an already destroyed aircraft.
signal changed(hp: float, maximum: float)
signal depleted
@export var max_hp: float = 100.0
var hp: float = 100.0
var _depleted: bool = false

func _ready() -> void:
	reset()

func take_damage(amount: float) -> void:
	if _depleted or not is_finite(amount) or amount <= 0.0:
		return
	set_hp(hp - amount)

func heal(amount: float) -> void:
	if is_finite(amount) and amount > 0.0:
		set_hp(hp + amount)

func set_hp(value: float) -> void:
	if not is_finite(value):
		return
	hp = clampf(value, 0.0, max_hp)
	changed.emit(hp, max_hp)
	if hp == 0.0 and not _depleted:
		_depleted = true
		depleted.emit()

func reset() -> void:
	_depleted = false
	hp = max_hp
	changed.emit(hp, max_hp)
