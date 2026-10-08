extends Node3D
var aircraft: FlightAircraft
var chase: ChaseCamera
var hud: FlightHUD
var enemy: EnemyAircraft

func _ready() -> void:
	var field := Airfield.new()
	field.name = "CountrysideAirfield"
	add_child(field)
	aircraft = FlightAircraft.new()
	aircraft.name = "Spitfire"
	add_child(aircraft)
	enemy = EnemyAircraft.new()
	enemy.name = "EnemyStuka"
	enemy.target = aircraft
	add_child(enemy)
	aircraft.collision_mask = 5 # terrain and enemy airframes
	aircraft.reset_completed.connect(enemy.reset_encounter)
	chase = ChaseCamera.new()
	chase.name = "ChaseCamera"
	chase.aircraft = aircraft
	add_child(chase)
	aircraft.reset_completed.connect(chase.snap)
	hud = FlightHUD.new()
	hud.aircraft = aircraft
	hud.enemy = enemy
	add_child(hud)

