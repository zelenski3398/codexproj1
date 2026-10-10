class_name AircraftDamage
extends Node3D
## Shared localized damage for every airframe. Supplies factors to the existing
## flight controller; it never changes a body transform or velocity.
signal component_changed(id: StringName, remaining: float, maximum: float)
signal fuel_fire_changed(burning: bool, local_source: Vector3)
const IDS: Array[StringName] = [&"fuselage", &"left_wing", &"right_wing", &"engine", &"cockpit", &"rudder", &"elevator", &"fuel_tank"]
@export var profile: AircraftDamageProfile
var aircraft: FlightAircraft
var definitions: Dictionary = {}
var integrity: Dictionary = {}
var hitboxes: Array[AircraftHitbox] = []
var hitbox_rids: Array[RID] = []
var selected_debug_component: StringName = &""
var debug_visible: bool = false
var _debug_update_queued: bool = false
var last_hit: StringName = &""
var last_hit_point: Vector3 = Vector3.ZERO
var fuel_remaining: float = 1.0
var fuel_leaking: bool = false
var fuel_burning: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	for definition in profile.components:
		definitions[definition.id] = definition
		integrity[definition.id] = definition.max_integrity
		var hitbox: AircraftHitbox = AircraftHitbox.new()
		hitbox.name = String(definition.id).to_pascal_case() + "Hitbox"
		hitbox.damage_system = self
		hitbox.definition = definition
		add_child(hitbox)
		hitboxes.append(hitbox)
		hitbox_rids.append(hitbox.get_rid())
	reset()

func reset() -> void:
	for id in definitions:
		var definition: AircraftComponentDefinition = definitions[id]
		integrity[id] = definition.max_integrity
		component_changed.emit(id, definition.max_integrity, definition.max_integrity)
	last_hit = &""
	last_hit_point = Vector3.ZERO
	fuel_remaining = 1.0
	fuel_leaking = false
	fuel_burning = false
	rng.seed = profile.fuel_random_seed
	fuel_fire_changed.emit(false, fuel_source())
	_refresh_debug()

func integrity_ratio(id: StringName) -> float:
	if not definitions.has(id):
		return 1.0
	var definition: AircraftComponentDefinition = definitions[id]
	return clampf(float(integrity[id]) / maxf(definition.max_integrity, 0.001), 0, 1)

func apply_damage(id: StringName, amount: float, point: Vector3 = Vector3.ZERO, force_fuel_hazards: bool = false) -> void:
	if not definitions.has(id) or not is_finite(amount) or amount <= 0 or aircraft.is_destroyed or aircraft.reset_pending:
		return
	var definition: AircraftComponentDefinition = definitions[id]
	integrity[id] = maxf(float(integrity[id]) - amount * definition.damage_multiplier, 0)
	last_hit = id
	last_hit_point = point
	if id == &"fuel_tank" and fuel_remaining > 0:
		if not fuel_leaking:
			fuel_leaking = force_fuel_hazards or rng.randf() < profile.fuel_leak_probability
		if not fuel_burning and (force_fuel_hazards or rng.randf() < profile.fuel_fire_probability):
			fuel_burning = true
			fuel_fire_changed.emit(true, fuel_source())
	component_changed.emit(id, float(integrity[id]), definition.max_integrity)
	# Whole-airframe HP still drives the existing one-shot destroyed state.
	# Separate configurable transfer lets mechanical failure precede hull death.
	aircraft.take_damage(amount * definition.airframe_multiplier)
	_refresh_debug()

func advance(delta: float) -> void:
	if aircraft.is_destroyed or aircraft.is_crashed:
		return
	var loss: float = profile.fuel_leak_rate * (1 - integrity_ratio(&"fuel_tank")) if fuel_leaking else 0.0
	if fuel_burning:
		loss += profile.fuel_burn_rate
		var definition: AircraftComponentDefinition = definitions[&"fuel_tank"]
		integrity[&"fuel_tank"] = maxf(float(integrity[&"fuel_tank"]) - profile.fuel_component_burn_per_second * delta, 0)
		component_changed.emit(&"fuel_tank", float(integrity[&"fuel_tank"]), definition.max_integrity)
		aircraft.take_damage(profile.fuel_fire_damage_per_second * delta)
	fuel_remaining = clampf(fuel_remaining - loss * delta, 0, 1)
	if fuel_remaining == 0 and fuel_burning:
		fuel_burning = false
		fuel_fire_changed.emit(false, fuel_source())
	if debug_visible and (fuel_burning or fuel_leaking):
		_refresh_debug()

func wing_efficiency(id: StringName) -> float:
	return 1 - profile.wing_lift_loss * (1 - integrity_ratio(id))

func lift_factor() -> float:
	return (wing_efficiency(&"left_wing") + wing_efficiency(&"right_wing")) * 0.5

func additional_drag() -> float:
	return profile.wing_drag_gain * (2 - integrity_ratio(&"left_wing") - integrity_ratio(&"right_wing")) * 0.5 + profile.fuselage_drag_gain * (1 - integrity_ratio(&"fuselage"))

func power_factor() -> float:
	return pow(integrity_ratio(&"engine"), profile.engine_power_exponent) if fuel_remaining > 0 else 0.0

func rudder_factor() -> float:
	return lerpf(profile.minimum_rudder_authority, 1, integrity_ratio(&"rudder"))

func elevator_factor() -> float:
	return lerpf(profile.minimum_elevator_authority, 1, integrity_ratio(&"elevator"))

func cockpit_factor() -> float:
	return lerpf(profile.minimum_cockpit_authority, 1, integrity_ratio(&"cockpit"))

func balance_torque(lift: float, q: float, lift_direction: Vector3, direction: Vector3, right: Vector3) -> Vector3:
	# Simplification: each half-wing carries half the original lift and drag at
	# a fixed spanwise arm. Retain central forces, add their asymmetric moments.
	var difference: float = wing_efficiency(&"right_wing") - wing_efficiency(&"left_wing")
	var moment: Vector3 = right.cross(lift_direction) * lift * 0.5 * profile.lift_lever_arm * difference
	var drag_difference: float = integrity_ratio(&"left_wing") - integrity_ratio(&"right_wing")
	moment += right.cross(-direction) * q * aircraft.wing_area * 0.5 * profile.wing_drag_gain * profile.lift_lever_arm * drag_difference * profile.asymmetric_drag_gain
	return moment

func fuel_source() -> Vector3:
	var definition: AircraftComponentDefinition = definitions.get(&"fuel_tank")
	return definition.hitboxes[0].position if definition != null and not definition.hitboxes.is_empty() else Vector3(0, 0, -1)

func set_debug_visible(enabled: bool) -> void:
	if debug_visible == enabled:
		return
	debug_visible = enabled
	_refresh_debug()

func set_debug_selection(id: StringName) -> void:
	if selected_debug_component != id:
		selected_debug_component = id
		_refresh_debug()

func _refresh_debug() -> void:
	# Debug materials update outside the physics callback, once per frame even
	# when multiple rounds or burn damage change integrity in the same tick.
	if not _debug_update_queued:
		_debug_update_queued = true
		call_deferred("_update_debug_now")

func _update_debug_now() -> void:
	_debug_update_queued = false
	if is_queued_for_deletion():
		return
	for hitbox in hitboxes:
		hitbox.update_debug(debug_visible, hitbox.definition.id == selected_debug_component)
