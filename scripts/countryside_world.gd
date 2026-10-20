class_name CountrysideWorld
extends MaltaWorld
## The retained test map uses the same persistent pilot/fleet/recovery owner.
## Its original terrain/runway/buildings stay in place; no geographic city load.
class EmptyFortBattery extends StElmoBattery:
	func _ready() -> void:pass
func _ready() -> void:
	name="CountrysideGroundWorld"
	var original:=Airfield.new()
	add_child(original)
	terrain=original
	var layout:=MaltaAirfield.new()
	layout.record={"id":"ta_qali","name":"Countryside test airfield","position":[0,0,0],"heading":0,"slope":0,"length":1800,"stationed_aircraft":["spitfire","sea_gladiator"]}
	for child in original.get_children():
		if child is AircraftHangar:layout.existing_hangars.append(child)
	add_child(layout)
	fields.ta_qali=layout
	var truck:=MilitaryTruck.new()
	add_child(truck)
	truck.position=Vector3(78,.04,570)
	trucks.append(truck)
	aa_battery=AirfieldAABattery.new()
	aa_battery.world=self
	add_child(aa_battery)
	fort_battery=EmptyFortBattery.new()
	add_child(fort_battery)
func _process(_delta: float) -> void:pass
