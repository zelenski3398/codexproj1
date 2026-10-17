class_name AircraftCrashSolver
extends RefCounted
## Dimensionless energy relative to a 3000 kg aircraft at 30 m/s. Contact
## normal separates normal impact energy from glancing/tangential energy.
static func assess(aircraft: FlightAircraft, velocity: Vector3, normal: Vector3, surface: String = "terrain") -> Dictionary:
	var profile := aircraft.components.profile
	var normal_speed: float = absf(velocity.dot(normal.normalized()))
	var tangent_squared: float = maxf(velocity.length_squared()-normal_speed*normal_speed,0)
	var structure: float = (aircraft.components.integrity_ratio(&"fuselage") + aircraft.components.integrity_ratio(&"left_wing") + aircraft.components.integrity_ratio(&"right_wing"))/3
	var material: float = 1.2 if surface == "hard" else (0.65 if surface == "water" else 1.0)
	var alignment: float = clampf(1-aircraft.global_basis.y.dot(normal),0,2)
	var energy: float = aircraft.mass / 3000.0 * (normal_speed*normal_speed + profile.horizontal_impact_fraction * tangent_squared) / 900.0
	energy *= material * (1 + (1-structure)*0.5 + alignment*0.25)
	var category: String = "controlled" if energy < profile.controlled_crash_limit else ("moderate" if energy < profile.moderate_crash_limit else ("severe" if energy < profile.severe_crash_limit else "catastrophic"))
	var burning: bool = not aircraft.components.fires.is_empty()
	# Fuel and fire alter ignition probability, never turn a gentle landing
	# into a high-energy detonation. Empty tanks cannot create a fuel fireball.
	var probability: float = profile.fuel_impact_ignition_probability * aircraft.components.fuel_remaining * clampf(energy/3,0,1)
	if burning: probability = minf(probability*2,0.95)
	var ignition: bool = energy >= profile.moderate_crash_limit and aircraft.components.fuel_remaining > 0.05 and aircraft.components.rng.randf() < probability
	return {"severity":energy,"category":category,"surface":surface,"normal_speed":normal_speed,"speed":velocity.length(),"mass":aircraft.mass,"fuel":aircraft.components.fuel_remaining,"burning":burning,"ignition":ignition}
