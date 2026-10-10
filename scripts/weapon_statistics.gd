class_name WeaponStatistics
extends RefCounted
## Accepted projectiles and actual hostile HP damage, never all ray impacts.
var shots: int = 0
var aircraft_hits: int = 0
var impacts: int = 0
var damage_dealt: float = 0
var component_hits: Dictionary = {}
var last_component: StringName = &""
var last_shot_distance: float = -1
var last_hit_distance: float = -1
var last_flight_time: float = 0
var ranged_shots: Dictionary = {}
var ranged_hits: Dictionary = {}
var generation: int = 0

func reset() -> void:
	generation += 1
	shots = 0
	aircraft_hits = 0
	impacts = 0
	damage_dealt = 0
	component_hits.clear()
	last_component = &""
	last_shot_distance = -1
	last_hit_distance = -1
	last_flight_time = 0
	ranged_shots.clear()
	ranged_hits.clear()

func range_bucket(distance: float) -> String:
	return "0–150" if distance < 150 else ("150–350" if distance < 350 else ("350–650" if distance < 650 else "650+"))

func record_shot(distance: float) -> void:
	shots += 1
	if distance >= 0:
		last_shot_distance = distance
		var bucket: String = range_bucket(distance)
		ranged_shots[bucket] = int(ranged_shots.get(bucket, 0)) + 1

func record_aircraft_hit(component: StringName, amount: float, distance: float, flight_time: float) -> void:
	aircraft_hits += 1
	damage_dealt += amount
	last_component = component
	last_hit_distance = distance
	last_flight_time = flight_time
	component_hits[component] = int(component_hits.get(component, 0)) + 1
	if distance >= 0:
		var bucket: String = range_bucket(distance)
		ranged_hits[bucket] = int(ranged_hits.get(bucket, 0)) + 1

func hit_percentage() -> float:
	return 100.0 * aircraft_hits / maxf(shots, 1)

func components_text() -> String:
	var values: PackedStringArray = []
	for id in AircraftDamage.IDS:
		if component_hits.has(id):
			values.append("%s %d" % [String(id).replace("_", " "), component_hits[id]])
	return ", ".join(values) if not values.is_empty() else "none"
