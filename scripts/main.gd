extends Node3D
var aircraft: FlightAircraft
var chase: ChaseCamera
var hud: FlightHUD

func _ready() -> void:
	var field := Airfield.new()
	field.name = "CountrysideAirfield"
	add_child(field)
	aircraft = FlightAircraft.new()
	aircraft.name = "Spitfire"
	add_child(aircraft)
	chase = ChaseCamera.new()
	chase.name = "ChaseCamera"
	chase.aircraft = aircraft
	add_child(chase)
	aircraft.reset_completed.connect(chase.snap)
	hud = FlightHUD.new()
	hud.aircraft = aircraft
	add_child(hud)

