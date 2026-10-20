class_name PilotSurvival
extends Node
## One persistent human life. Hull depletion is NOT an injury event.
@export var impact_safe_severity: float = .18
@export var impact_damage_scale: float = 42.0
@export var cockpit_damage_scale: float = 55.0
@export var fire_damage_per_second: float = 9.0
@export var explosion_damage: float = 110.0
var mission: MaltaMission
var departure_airfield: String
var impact_latches: Dictionary = {}
var blast_latches: Dictionary = {}
var died: bool = false
var death_panel: PanelContainer
func _ready() -> void:
	departure_airfield = mission.home
	mission.pilot.combat_enabled = true
	mission.pilot.add_to_group("damageable_ground_pilots")
	mission.pilot.health.depleted.connect(_died)
	for aircraft in mission.fleet:
		aircraft.impact_assessed.connect(_impact.bind(aircraft))
		aircraft.components.component_hit.connect(_component_hit.bind(aircraft))
	death_panel = PanelContainer.new()
	death_panel.position = Vector2(440,270)
	death_panel.custom_minimum_size = Vector2(530,180)
	mission.canvas.add_child(death_panel)
	var column := VBoxContainer.new()
	death_panel.add_child(column)
	var title := Label.new()
	title.text = "PILOT KILLED\nThis attempt has ended."
	title.add_theme_font_size_override("font_size",26)
	column.add_child(title)
	var retry := Button.new()
	retry.text = "RESTART ATTEMPT"
	retry.pressed.connect(mission.session.restart_malta,CONNECT_DEFERRED)
	column.add_child(retry)
	var menu := Button.new()
	menu.text = "RETURN TO MENU"
	menu.pressed.connect(mission.session.show_selection,CONNECT_DEFERRED)
	column.add_child(menu)
	death_panel.hide()
func alive() -> bool: return not died and mission.pilot.health.hp > 0
func _impact(result: Dictionary, aircraft: FlightAircraft) -> void:
	if mission.occupied != aircraft or impact_latches.has(aircraft.get_instance_id()) or not alive(): return
	impact_latches[aircraft.get_instance_id()] = true
	var damage := maxf(float(result.get("severity",0))-impact_safe_severity,0)*impact_damage_scale
	if result.get("ignition",false): damage += explosion_damage*.55
	mission.pilot.take_damage(damage)
func _component_hit(id: StringName, _point: Vector3, severity: float, aircraft: FlightAircraft) -> void:
	if mission.occupied == aircraft and id in [&"cockpit",&"pilot"]:
		mission.pilot.take_damage(severity*cockpit_damage_scale)
func _physics_process(delta: float) -> void:
	if not alive() or get_tree().paused: return
	var occupied: FlightAircraft = mission.occupied
	if is_instance_valid(occupied):
		# Seat collision follows the aircraft, while its independent health lives on.
		mission.pilot.global_position = occupied.to_global(Vector3(0,.5,.2))
	var point: Vector3 = occupied.global_position if is_instance_valid(occupied) else mission.pilot.global_position
	for aircraft in get_tree().get_nodes_in_group("combat_aircraft"):
		if not is_instance_valid(aircraft): continue
		var distance := point.distance_to(aircraft.global_position)
		if (aircraft.components.catastrophic_ignition or aircraft.impact_effects.explosion_count>0) and not blast_latches.has(aircraft.get_instance_id()):
			blast_latches[aircraft.get_instance_id()] = true
			if distance < 15: mission.pilot.take_damage(explosion_damage*(1-distance/15))
		if not aircraft.components.fires.is_empty() and distance < 7:
			mission.pilot.take_damage(fire_damage_per_second*delta*(1-distance/7))
func _died() -> void:
	if died: return
	died = true
	if is_instance_valid(mission.occupied):
		mission.occupied.input_enabled=false
		mission.occupied.pilot.automated=true
		mission.occupied.pilot.reset_commands()
	if is_instance_valid(mission.interaction.occupied_gun):mission.interaction.occupied_gun.stop_operation()
	if is_instance_valid(mission.interaction.occupied_vehicle):mission.interaction.occupied_vehicle.stop_driving()
	mission.session.encounters.pilot_died()
	if is_instance_valid(mission.session.interception):mission.session.interception._finish(false,"Pilot killed — interception failed")
	if is_instance_valid(mission.session.harbour):mission.session.harbour._queue_resolution()
	if is_instance_valid(mission.session.aa_defence):mission.session.aa_defence._queue_resolution()
	death_panel.show()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
