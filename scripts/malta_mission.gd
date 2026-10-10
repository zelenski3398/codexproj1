class_name MaltaMission
extends Node
## Owns one persistent fleet and pilot. Boarding only routes input/HUD/AI target;
## it never resets health, components, fuel, physics, projectiles or the terrain.
@export var boarding_range: float = 8.0
@export var maximum_exit_speed: float = 1.5
var session: Node3D
var world: MaltaWorld
var home: String = "ta_qali"
var initial_kind: String = "spitfire"
var fleet: Array[FlightAircraft] = []
var pilot: GroundPilot
var occupied: FlightAircraft
var initial_aircraft: FlightAircraft
var canvas: CanvasLayer
var status: Label
var chart_panel: PanelContainer
var chart: MaltaChart
var notice: String = ""
var notice_time: float = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id in world.fields:
		var field: MaltaAirfield = world.fields[id]
		var kinds: Array = field.record.stationed_aircraft.duplicate()
		if id == home and kinds.has(initial_kind):
			kinds.erase(initial_kind)
			kinds.push_front(initial_kind)
		for i in range(kinds.size()):
			var aircraft: FlightAircraft = SeaGladiator.new() if kinds[i] == "sea_gladiator" else FlightAircraft.new()
			aircraft.process_mode = Node.PROCESS_MODE_PAUSABLE
			aircraft.name = id + "_" + kinds[i]
			aircraft.reset_position = field.parking[i].origin
			aircraft.input_enabled = false
			aircraft.engine_running = false
			aircraft.fuel_consumption_rate = 1.0 / 7200.0
			add_child(aircraft)
			aircraft.global_transform = field.parking[i]
			aircraft.pilot.automated = true
			aircraft.pilot.brakes = true
			aircraft.collision_mask = 7
			fleet.append(aircraft)
			if id == home and i == 0:
				initial_aircraft = aircraft
	pilot = GroundPilot.new()
	pilot.name = "GroundPilot"
	pilot.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(pilot)
	pilot.global_position = world.fields[home].pilot_spawn
	pilot.yaw = -deg_to_rad(float(world.fields[home].record.heading))
	_build_ui()
	set_process_input(true)

func _build_ui() -> void:
	canvas = CanvasLayer.new()
	canvas.layer = 8
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	status = Label.new()
	status.position = Vector2(32, 32)
	status.add_theme_font_size_override("font_size", 19)
	status.add_theme_color_override("font_color", Color("eee7ce"))
	status.add_theme_color_override("font_shadow_color", Color("13252a"))
	status.add_theme_constant_override("shadow_offset_x", 2)
	status.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(status)
	chart_panel = PanelContainer.new()
	chart_panel.position = Vector2(340, 35)
	chart_panel.size = Vector2(740, 810)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("101e25")
	style.set_content_margin_all(15)
	chart_panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(chart_panel)
	var column: VBoxContainer = VBoxContainer.new()
	chart_panel.add_child(column)
	var title: Label = Label.new()
	title.text = "MALTA · NAVIGATION    /    M TO CLOSE"
	column.add_child(title)
	chart = MaltaChart.new()
	chart.home = home
	chart.show_player = true
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(chart)
	var legend: Label = Label.new()
	legend.text = "WHITE: you / heading    GOLD: home    RED: detected enemy\nMap does not pause flight. North is up; grid spacing 5 km."
	column.add_child(legend)
	chart_panel.visible = false

func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("navigation_map"):
		chart_panel.visible = not chart_panel.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("board") and not get_tree().paused:
		call_deferred("leave_aircraft" if is_instance_valid(occupied) else "board_nearest")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("engine") and is_instance_valid(occupied) and not get_tree().paused:
		if occupied.is_destroyed or occupied.is_crashed or occupied.components.power_factor() <= 0:
			_message("Engine unserviceable")
		else:
			occupied.engine_running = not occupied.engine_running
			_message("Engine running" if occupied.engine_running else "Engine stopped")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("reset") and not is_instance_valid(occupied):
		session.call_deferred("restart_malta")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and not is_instance_valid(occupied):
		get_tree().paused = not get_tree().paused
		get_viewport().set_input_as_handled()

func nearest_serviceable() -> FlightAircraft:
	var nearest: FlightAircraft
	var distance: float = boarding_range
	for aircraft in fleet:
		if not is_instance_valid(aircraft) or aircraft.is_destroyed or aircraft.is_crashed or aircraft.airspeed > maximum_exit_speed or aircraft.gear.contact_count == 0:
			continue
		var current: float = pilot.global_position.distance_to(aircraft.global_position)
		if current < distance:
			distance = current
			nearest = aircraft
	return nearest

func board_nearest() -> bool:
	var aircraft: FlightAircraft = nearest_serviceable()
	if aircraft == null:
		_message("Walk within 8 m of a stopped, serviceable aircraft")
		return false
	return board_aircraft(aircraft)

func board_aircraft(aircraft: FlightAircraft) -> bool:
	# Keep the same validation for calls from UI and tests; no remote boarding.
	if occupied != null or aircraft != nearest_serviceable():
		return false
	occupied = aircraft
	pilot.set_active(false)
	aircraft.input_enabled = true
	aircraft.pilot.reset_commands()
	aircraft.pilot.automated = false
	session.attach_malta_player(aircraft)
	if is_instance_valid(session.enemy):
		session.enemy.target = aircraft
		session.enemy.ai.target = aircraft
		aircraft.guns.telemetry_target = session.enemy
		session.enemy.guns.telemetry_target = aircraft
	_message("I starts engine · W sets throttle · taxi onto the runway")
	return true

func leave_aircraft() -> bool:
	if not is_instance_valid(occupied):
		return false
	if occupied.is_destroyed or occupied.is_crashed or occupied.airspeed > maximum_exit_speed or occupied.gear.contact_count == 0:
		_message("Stop on the ground before leaving · R restarts a lost mission")
		return false
	if occupied.engine_running or occupied.pilot.throttle > 0.01:
		_message("Reduce throttle with S and stop the engine with I before leaving")
		return false
	# Find a clear ground position on either side, never in a wing/building.
	var exit: Vector3
	var found: bool = false
	for side in [1.0, -1.0]:
		var point: Vector3 = occupied.global_position + occupied.global_basis.x * side * 6.5 + occupied.global_basis.z * 2
		var space: PhysicsDirectSpaceState3D = occupied.get_world_3d().direct_space_state
		var floor_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 10, point + Vector3.DOWN * 20, 1)
		var floor_hit: Dictionary = space.intersect_ray(floor_query)
		if floor_hit.is_empty():
			continue
		exit = floor_hit.position + Vector3.UP * 1.05
		var shape: CapsuleShape3D = CapsuleShape3D.new()
		shape.radius = 0.4
		shape.height = 1.9
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, exit)
		query.collision_mask = 7
		if space.intersect_shape(query).is_empty():
			found = true
			break
	if not found:
		_message("No safe exit beside the aircraft; taxi to open ground")
		return false
	occupied.input_enabled = false
	occupied.pilot.automated = true
	occupied.pilot.reset_commands()
	occupied.pilot.brakes = true
	occupied = null
	pilot.global_position = exit
	pilot.velocity = Vector3.ZERO
	pilot.set_active(true)
	if is_instance_valid(session.hud):
		session.hud.visible = false
		session.hud.flight_input_enabled = false
	if is_instance_valid(session.enemy):
		session.enemy.target = null
		session.enemy.ai.target = null
	_message("Aircraft parked; damage and fuel retained. Walk to another aircraft and press E.")
	return true

func _message(value: String) -> void:
	notice = value
	notice_time = 5

func _process(delta: float) -> void:
	if not get_tree().paused:
		notice_time = maxf(notice_time - delta, 0)
	var position: Vector3 = occupied.global_position if is_instance_valid(occupied) else pilot.global_position
	var heading: Vector3 = -occupied.global_basis.z if is_instance_valid(occupied) else -Basis(Vector3.UP, pilot.yaw).z
	chart.player_position = position
	chart.player_heading = heading
	chart.show_contact = is_instance_valid(session.enemy) and not session.enemy.is_destroyed and position.distance_to(session.enemy.global_position) < session.enemy.ai.detection_range
	if chart.show_contact:
		chart.contact_position = session.enemy.global_position
	status.position = Vector2(32, 150) if is_instance_valid(occupied) else Vector2(32, 32)
	if is_instance_valid(occupied):
		status.text = "MALTA · %s    M Map    E Leave    I Engine %s\nFUEL %d%% · home %s" % [occupied.display_name, "ON" if occupied.engine_running else "OFF", roundi(occupied.components.fuel_remaining * 100), world.fields[home].record.name]
	else:
		var nearest: FlightAircraft = nearest_serviceable()
		status.text = "WINGS OVER MALTA · ON FOOT\nWASD Walk · Arrows Turn · M Map · ESC Pause · R Full restart\n" + ("E Board " + nearest.display_name if nearest != null else "Walk to an aircraft · E boards within 8 m")
	if get_tree().paused and not is_instance_valid(occupied):
		status.text += "\nPAUSED · ESC resumes"
	if notice_time > 0:
		status.text += "\n" + notice
