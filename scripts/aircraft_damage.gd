class_name AircraftDamage
extends Node3D
## Shared localized damage for every airframe. Supplies factors to the existing
## flight controller; it never changes a body transform or velocity.
signal component_changed(id: StringName, remaining: float, maximum: float)
signal component_hit(id: StringName, point: Vector3, severity: float)
signal component_failed(id: StringName)
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
var tank_fuel: Dictionary = {}
var leaking_tanks: Dictionary = {}
var fires: Dictionary = {}
var detached: Dictionary = {}
var fatigue: Dictionary = {}
var structural_hits: Dictionary = {}
var engine_seized: Dictionary = {}
var engine_temperature: Dictionary = {}
var catastrophic: bool = false
var catastrophic_ignition: bool = false
var last_source: String = "bullet"
var structural_load: float = 1.0
var leak_rate: float = 0.0
var misfire_clock: float = 0
var fire_clock: float = 0.0
var structure_clock: float = 0.0
var last_velocity: Vector3 = Vector3.ZERO
var velocity_valid: bool = false
var fuel_remaining: float = 1.0:
	get:
		var total: float = 0.0
		var capacity: float = 0.0
		for id in tank_fuel:
			total += float(tank_fuel[id])
			capacity += definitions[id].tank_capacity
		return total / maxf(capacity, 0.001)
	set(value):
		for id in tank_fuel:
			tank_fuel[id] = clampf(value, 0, 1) * definitions[id].tank_capacity
var fuel_leaking: bool = false
var fuel_burning: bool = false
var fuel_rng: RandomNumberGenerator = RandomNumberGenerator.new()
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
	tank_fuel.clear()
	leaking_tanks.clear()
	fires.clear()
	detached.clear()
	fatigue.clear()
	structural_hits.clear()
	engine_seized.clear()
	engine_temperature.clear()
	catastrophic = false
	catastrophic_ignition = false
	velocity_valid = false
	structural_load = 1
	structure_clock = 0
	fire_clock = 0
	misfire_clock = 0
	leak_rate = 0
	for id in definitions:
		var definition: AircraftComponentDefinition = definitions[id]
		integrity[id] = definition.max_integrity
		if definition.role == "fuel": tank_fuel[id] = definition.tank_capacity
		component_changed.emit(id, definition.max_integrity, definition.max_integrity)
	last_hit = &""
	last_hit_point = Vector3.ZERO
	fuel_remaining = 1.0
	fuel_leaking = false
	fuel_burning = false
	rng.seed = profile.damage_seed
	fuel_rng.seed = profile.fuel_random_seed
	fuel_fire_changed.emit(false, fuel_source())
	_refresh_debug()

func integrity_ratio(id: StringName) -> float:
	if not definitions.has(id):
		return 1.0
	var definition: AircraftComponentDefinition = definitions[id]
	return clampf(float(integrity[id]) / maxf(definition.max_integrity, 0.001), 0, 1)

func component_ids(role: String = "") -> Array[StringName]:
	var result: Array[StringName] = []
	for id in definitions:
		if role.is_empty() or definitions[id].role == role: result.append(id)
	return result

func component_state(id: StringName) -> String:
	var ratio := integrity_ratio(id)
	if ratio <= 0: return "destroyed"
	var thresholds: Vector3 = definitions[id].state_thresholds
	if ratio <= thresholds.z: return "critical"
	if ratio <= thresholds.y: return "moderate"
	if ratio <= thresholds.x: return "light"
	return "healthy"

func source_position(id: StringName) -> Vector3:
	var definition: AircraftComponentDefinition = definitions.get(id)
	return definition.hitboxes[0].position if definition != null and not definition.hitboxes.is_empty() else Vector3.ZERO

func apply_damage(id: StringName, amount: float, point: Vector3 = Vector3.ZERO, force_fuel_hazards: bool = false, source: String = "bullet") -> void:
	if not definitions.has(id) or not is_finite(amount) or amount <= 0 or aircraft.is_destroyed or aircraft.reset_pending or detached.has(id): return
	var definition: AircraftComponentDefinition = definitions[id]
	var previous: float = integrity[id]
	integrity[id] = maxf(previous - amount * definition.damage_multiplier, 0)
	last_hit = id
	last_hit_point = point
	last_source = source
	if source in ["shell","flak","explosion"] and amount > 25: structural_hits[id] = true
	if definition.role == "fuel" and float(tank_fuel.get(id, 0)) > 0:
		if not leaking_tanks.has(id) and (force_fuel_hazards or fuel_rng.randf() < profile.fuel_leak_probability): leaking_tanks[id] = true
		# Incendiary/explosive projectiles can ignite fuel; ordinary bullets retain
		# the configurable legacy small ignition chance, never certain ignition.
		if force_fuel_hazards or fuel_rng.randf() < profile.fuel_fire_probability: ignite(id)
	if definition.role == "engine" and integrity_ratio(id) < 0.25 and source in ["shell", "explosion"] and rng.randf() < profile.tank_ignition_probability: ignite(id)
	if previous > 0 and integrity[id] <= 0:
		if definition.role == "engine": engine_seized[id] = true
		if definition.role == "fuel": leaking_tanks[id] = true
		component_failed.emit(id)
	component_changed.emit(id, integrity[id], definition.max_integrity)
	component_hit.emit(id, point, clampf(amount / definition.max_integrity, 0, 1))
	# Hull loss remains available to mission rules, but a mechanical component
	# can fail first. No hull-depletion handler requests an automatic fireball.
	var transferred: float = amount if source in ["shell", "flak", "explosion"] else minf(amount, previous/maxf(definition.damage_multiplier,0.001))
	if previous > 0 or source in ["shell", "flak", "explosion"]: aircraft.take_damage(transferred * definition.airframe_multiplier)
	if id == &"cockpit" and integrity[id] <= 0: aircraft.take_damage(aircraft.health.max_hp)
	_refresh_debug()

func ignite(id: StringName) -> void:
	if not definitions.has(id) or not definitions[id].combustible or detached.has(id): return
	if definitions[id].role == "fuel" and float(tank_fuel.get(id,0)) <= 0: return
	if not fires.has(id):
		fires[id] = 0.35
		if aircraft.impact_effects != null: aircraft.impact_effects._play_event(&"fuel_ignition")
	_sync_hazards()

func _sync_hazards() -> void:
	fuel_leaking = not leaking_tanks.is_empty()
	fuel_burning = false
	for id in fires:
		if definitions[id].role == "fuel": fuel_burning = true
	fuel_fire_changed.emit(fuel_burning, fuel_source())

func advance(delta: float) -> void:
	if aircraft.is_crashed: return
	# Fire continues on a disabled wreck until impact; mission loss doesn't
	# extinguish fuel. Mechanical damage application stays blocked after loss.
	leak_rate = 0
	misfire_clock = maxf(misfire_clock-delta,0)
	for engine in component_ids("engine"):
		var heat: float = float(engine_temperature.get(engine,0))
		var running: bool = aircraft.engine_running and aircraft.pilot.throttle > 0.6 and integrity_ratio(engine) < 0.25 and integrity_ratio(engine) > 0
		heat = maxf(heat + delta * (profile.engine_heat_rate * aircraft.pilot.throttle if running else -profile.engine_cooling_rate),0)
		engine_temperature[engine] = heat
		if heat >= profile.engine_seizure_temperature and not engine_seized.has(engine):
			engine_seized[engine] = true
			aircraft.impact_effects._play_event(&"engine_seizure", source_position(engine))
		if running and misfire_clock <= 0 and not engine_seized.has(engine):
			aircraft.impact_effects._play_event(&"engine_misfire", source_position(engine))
			misfire_clock = 1.8
	for id in tank_fuel:
		var rate: float = profile.fuel_leak_rate * (1 - integrity_ratio(id)) if leaking_tanks.has(id) else 0.0
		if integrity_ratio(id) <= 0: rate *= profile.destroyed_tank_loss_multiplier
		if fires.has(id): rate += profile.fuel_burn_rate
		var loss: float = minf(float(tank_fuel[id]), rate * delta)
		tank_fuel[id] = maxf(float(tank_fuel[id]) - loss, 0)
		leak_rate += loss / maxf(delta, 0.0001)
		if tank_fuel[id] <= 0:
			fires.erase(id)
			leaking_tanks.erase(id)
	fire_clock += delta
	if fire_clock >= profile.fire_step_seconds:
		var step: float = fire_clock
		fire_clock = 0
		_fire_step(step)
	structure_clock += delta
	_sync_hazards()
	if debug_visible and (not fires.is_empty() or fuel_leaking): _refresh_debug()

func _fire_step(delta: float) -> void:
	for id in fires.keys():
		if detached.has(id):
			fires.erase(id)
			continue
		var definition: AircraftComponentDefinition = definitions[id]
		# Oil/engine fires eventually burn out without supplied fuel; fuel fires
		# extinguish when that tank empties. Structural material burns more slowly.
		if fuel_remaining <= 0 and definition.role == "engine":
			fires[id] = maxf(float(fires[id]) - delta * 0.12, 0)
			if fires[id] <= 0: fires.erase(id); continue
		else: fires[id] = minf(float(fires[id]) + delta * 0.06, 1)
		var burn_rate: float = profile.fuel_component_burn_per_second if definition.role == "fuel" else profile.fire_damage_per_second
		var burn: float = burn_rate * float(fires[id]) * delta
		integrity[id] = maxf(float(integrity[id]) - burn, 0)
		component_changed.emit(id, integrity[id], definition.max_integrity)
		for neighbour in definition.adjacent:
			if definitions.has(neighbour) and not fires.has(neighbour) and integrity_ratio(neighbour) < 0.85 and rng.randf() < 1-exp(-profile.fire_spread_probability_per_second * delta): ignite(neighbour)
		# A badly compromised, still-fuelled burning tank can detonate, once.
		if not catastrophic and definition.role == "fuel" and integrity_ratio(id) < 0.12 and float(tank_fuel.get(id,0)) > 0.08 and rng.randf() < 1-exp(-profile.tank_ignition_probability * delta): catastrophic_failure("Fuel tank ignition")
		if definition.role in ["structure", "wing"] and integrity_ratio(id) <= 0 and not catastrophic: catastrophic_failure("Fire consumed primary structure", false)
	if not aircraft.is_destroyed and not fires.is_empty(): aircraft.take_damage(profile.fuel_fire_damage_per_second * delta)

func catastrophic_failure(reason: String, explosive: bool = true) -> void:
	if catastrophic: return
	catastrophic = true
	catastrophic_ignition = explosive and fuel_remaining > 0.05
	aircraft.set_meta("failure_reason", reason)
	aircraft.impact_effects.start()
	aircraft.take_damage(aircraft.health.max_hp)

func evaluate_structure(delta: float, velocity: Vector3, angular: Vector3) -> void:
	if velocity_valid:
		structural_load = clampf(((velocity-last_velocity)/maxf(delta,0.0001)-Vector3.DOWN*9.81).length()/9.81,0,30)
	last_velocity = velocity
	velocity_valid = true
	if structure_clock < profile.structural_check_seconds or aircraft.gear.contact_count > 0 or aircraft.is_crashed: return
	var interval: float = structure_clock
	structure_clock = 0
	for id in definitions:
		var definition: AircraftComponentDefinition = definitions[id]
		var ratio := integrity_ratio(id)
		if not definition.detachable or detached.has(id): continue
		if definition.role == "engine" and not structural_hits.has(id): continue
		# Destroyed sections separate; critically weakened sections accumulate
		# fatigue only under excess load or speed. Random draws occur per event.
		var load_ratio: float = structural_load / maxf(definition.structural_limit_g * maxf(ratio,0.18),0.1)
		var speed_ratio: float = velocity.length() / maxf(definition.structural_speed * maxf(sqrt(ratio),0.35),1)
		var stress: float = maxf(load_ratio,speed_ratio) + angular.length()*0.05
		if ratio > definition.minimum_failure_ratio: continue
		if ratio <= 0:
			detach(id)
		elif stress > 1.0:
			fatigue[id] = float(fatigue.get(id,0)) + (stress-1) * interval * profile.structural_fatigue_rate
			if fatigue[id] >= 1 or rng.randf() < 1-exp(-profile.structural_failure_probability * (stress-1) * interval): detach(id)

func detach(id: StringName) -> void:
	if detached.has(id) or not definitions.has(id) or not definitions[id].detachable: return
	detached[id] = true
	integrity[id] = 0
	fires.erase(id)
	component_changed.emit(id, 0, definitions[id].max_integrity)
	aircraft.impact_effects.detach_component(id)
	if id in [&"left_wing", &"right_wing"]:
		for neighbour in definitions[id].adjacent:
			if definitions.has(neighbour) and definitions[neighbour].role in ["engine","fuel","control"]:
				integrity[neighbour] = 0
				detached[neighbour] = true
				if definitions[neighbour].role == "engine": engine_seized[neighbour] = true
				if tank_fuel.has(neighbour): tank_fuel[neighbour] = 0
				fires.erase(neighbour)
				component_changed.emit(neighbour,0,definitions[neighbour].max_integrity)
	if id == &"tail":
		for control in [&"rudder", &"elevator"]:
			if not definitions.has(control): continue
			integrity[control] = 0
			detached[control] = true
	if id in [&"left_wing", &"right_wing", &"tail"]:
		aircraft.set_meta("failure_reason", String(id)+" separated")
	_refresh_debug()

func consume_fuel(full_capacity_fraction: float) -> void:
	if full_capacity_fraction <= 0 or fuel_remaining <= 0: return
	var total: float = 0
	var capacity: float = 0
	for id in tank_fuel:
		if integrity_ratio(id) > 0: total += tank_fuel[id]
		capacity += definitions[id].tank_capacity
	var factor: float = maxf(1-full_capacity_fraction*capacity/maxf(total,0.0001),0)
	for id in tank_fuel:
		if integrity_ratio(id) > 0: tank_fuel[id] *= factor

func engine_power(id: StringName) -> float:
	if detached.has(id) or engine_seized.has(id) or integrity_ratio(id) <= 0: return 0
	var available: float = 0
	var capacity: float = 0
	for tank in tank_fuel:
		capacity += definitions[tank].tank_capacity
		if integrity_ratio(tank) > 0: available += tank_fuel[tank]
	var pressure: float = clampf(available / maxf(capacity * profile.low_fuel_pressure_threshold,0.0001),0,1)
	var power: float = pow(integrity_ratio(id),profile.engine_power_exponent)*pressure
	if integrity_ratio(id) < 0.25:
		# Continuous rough running, independent of rendered frame rate.
		power *= 0.7 + 0.3 * sin(aircraft.airborne_time * 19.0 + definitions[id].propeller_index)
	return power

func roll_factor(command: float = 0) -> float:
	var left: float = integrity_ratio(&"left_aileron")
	var right: float = integrity_ratio(&"right_aileron")
	return clampf(0.5*(left+right) + signf(command)*0.25*(right-left),0,1)

func asymmetry_torque(thrust: float, basis: Basis) -> Vector3:
	var result := Vector3.ZERO
	var weight: float = 0
	for id in component_ids("engine"): weight += definitions[id].thrust_weight
	for id in component_ids("engine"):
		var force: Vector3 = -basis.z * thrust * engine_power(id) * definitions[id].thrust_weight / maxf(weight,0.001)
		result += (basis * source_position(id)).cross(force) * profile.engine_asymmetry_lever
	return result

func wing_efficiency(id: StringName) -> float:
	return 0.0 if detached.has(id) else 1 - profile.wing_lift_loss * (1 - integrity_ratio(id))

func lift_factor() -> float:
	return (wing_efficiency(&"left_wing") + wing_efficiency(&"right_wing")) * 0.5

func additional_drag() -> float:
	return profile.failed_propeller_drag * (1 - power_factor()) + profile.wing_drag_gain * (2 - integrity_ratio(&"left_wing") - integrity_ratio(&"right_wing")) * 0.5 + profile.fuselage_drag_gain * (1 - integrity_ratio(&"fuselage"))

func power_factor() -> float:
	var power: float = 0
	var weight: float = 0
	for id in component_ids("engine"):
		var share: float = definitions[id].thrust_weight
		power += engine_power(id)*share
		weight += share
	return power / maxf(weight,0.001)

func rudder_factor() -> float:
	if not definitions.has(&"rudder"): return 1.0
	return 0.0 if detached.has(&"tail") or integrity_ratio(&"rudder") <= definitions[&"rudder"].jam_threshold else lerpf(profile.minimum_rudder_authority, 1, integrity_ratio(&"rudder"))

func elevator_factor() -> float:
	if not definitions.has(&"elevator"): return 1.0
	return 0.0 if detached.has(&"tail") or integrity_ratio(&"elevator") <= definitions[&"elevator"].jam_threshold else lerpf(profile.minimum_elevator_authority, 1, integrity_ratio(&"elevator"))

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
	for id in fires:
		if definitions[id].role == "fuel": return source_position(id)
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
