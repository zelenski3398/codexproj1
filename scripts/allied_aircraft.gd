class_name AlliedAircraft
extends RefCounted
## Shared player/Allied factory; mission formations opt into definitions explicitly.
const KINDS: Array[String] = ["spitfire", "sea_gladiator", "hurricane"]
static func create(kind: String) -> FlightAircraft:
	match kind:
		"sea_gladiator":return SeaGladiator.new()
		"hurricane":return preload("res://aircraft/hurricane_mk_i.tscn").instantiate()
	return FlightAircraft.new()
static func kind_of(plane: FlightAircraft) -> String:
	if plane is HawkerHurricane:return "hurricane"
	return "sea_gladiator" if plane is SeaGladiator else "spitfire"
static func title(kind: String) -> String:
	return {"spitfire":"Spitfire Mk I","sea_gladiator":"Gloster Sea Gladiator","hurricane":"Hawker Hurricane Mk I"}.get(kind,kind)
static func roster(record: Dictionary) -> Array:
	var result: Array=record.stationed_aircraft.duplicate()
	if not result.has("hurricane"):result.append("hurricane")
	return result
