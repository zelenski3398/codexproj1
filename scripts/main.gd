extends Node3D
var aircraft: FlightAircraft
var chase: ChaseCamera
var hud: FlightHUD
var enemy: EnemyAircraft
var selector: AircraftSelector
var selected_aircraft: String = "spitfire"

func _ready() -> void:
	var field := Airfield.new()
	field.name = "CountrysideAirfield"
	add_child(field)
	show_selection()

func show_selection() -> void:
	get_tree().paused = false
	get_viewport().gui_release_focus()
	# Removing nodes before queue_free prevents old pilots/HUD consuming input
	# and old world-space rounds persisting when returning from the pause menu.
	for node in [hud, enemy, aircraft, chase, selector]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	aircraft = null
	enemy = null
	chase = null
	hud = null
	selector = AircraftSelector.new()
	selector.name = "AircraftSelection"
	selector.chosen.connect(start_flight, CONNECT_DEFERRED)
	add_child(selector)
	selector.select(selected_aircraft)

func start_flight(kind: String) -> void:
	if is_instance_valid(aircraft) or kind not in ["spitfire", "sea_gladiator"]:
		return
	selected_aircraft = kind
	if is_instance_valid(selector):
		remove_child(selector)
		selector.queue_free()
	selector = null
	get_viewport().gui_release_focus()
	aircraft = SeaGladiator.new() if kind == "sea_gladiator" else FlightAircraft.new()
	aircraft.name = "SeaGladiator" if kind == "sea_gladiator" else "Spitfire"
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
	hud.change_aircraft_requested.connect(show_selection, CONNECT_DEFERRED)

