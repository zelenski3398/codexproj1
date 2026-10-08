extends Node3D
var aircraft: FlightAircraft
var chase: ChaseCamera
var hud: FlightHUD
var practice_target: PracticeTarget

func _ready() -> void:
	var field := Airfield.new()
	field.name = "CountrysideAirfield"
	add_child(field)
	aircraft = FlightAircraft.new()
	aircraft.name = "Spitfire"
	add_child(aircraft)
	practice_target = PracticeTarget.new()
	practice_target.name = "PracticeTarget"
	add_child(practice_target)
	aircraft.reset_completed.connect(practice_target.reset_target)
	chase = ChaseCamera.new()
	chase.name = "ChaseCamera"
	chase.aircraft = aircraft
	add_child(chase)
	aircraft.reset_completed.connect(chase.snap)
	hud = FlightHUD.new()
	hud.aircraft = aircraft
	add_child(hud)

