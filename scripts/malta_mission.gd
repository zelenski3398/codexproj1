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
var initial_spawn_id: String = ""
var travel_picker: OptionButton
var travel_button: Button
var fleet: Array[FlightAircraft] = []
var pilot: GroundPilot
var occupied: FlightAircraft
var survival: PilotSurvival
var recovery: TransportRecovery
var interaction: AirfieldInteraction
var last_abandoned: FlightAircraft
var initial_aircraft: FlightAircraft
var canvas: CanvasLayer
var status: Label
var chart_panel: PanelContainer
var aa_settings: PanelContainer
var aa_sensitivity: HSlider
var aa_sensitivity_label: Label
var chart: MaltaChart
var notice: String = ""
var notice_time: float = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id in world.fields:
		var field: MaltaAirfield = world.fields[id]
		var kinds: Array = field.record.stationed_aircraft.duplicate()
		# Mission-local roster: leave the shared airfield/free-roam records intact.
		if session.game_mode == "harbour" and id == home:
			kinds = ["sea_gladiator", "sea_gladiator", "sea_gladiator"]
		if id == home and kinds.has(initial_kind):
			kinds.erase(initial_kind)
			kinds.push_front(initial_kind)
		for i in range(kinds.size()):
			var aircraft: FlightAircraft = SeaGladiator.new() if kinds[i] == "sea_gladiator" else FlightAircraft.new()
			aircraft.process_mode = Node.PROCESS_MODE_PAUSABLE
			aircraft.name = id + "_" + kinds[i]
			if kinds.count(kinds[i]) > 1: aircraft.name += "_" + str(i + 1)
			aircraft.reset_position = field.parking[i].origin
			aircraft.input_enabled = false
			aircraft.engine_running = false
			aircraft.fuel_consumption_rate = 1.0 / 7200.0
			add_child(aircraft)
			aircraft.global_transform = field.parking[i]
			aircraft.pilot.automated = true
			aircraft.pilot.brakes = true
			aircraft.collision_mask = 7
			aircraft.impact_effects.preserve_wreck_remains = true
			aircraft.destroyed.connect(session.encounters.player_destroyed.bind(aircraft))
			fleet.append(aircraft)
			if id == home and i == 0:
				initial_aircraft = aircraft
	pilot = GroundPilot.new()
	pilot.name = "GroundPilot"
	pilot.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(pilot)
	pilot.global_position = world.fields[home].pilot_spawn
	pilot.yaw = -deg_to_rad(float(world.fields[home].record.heading))
	if StElmoLocations.is_fort(initial_spawn_id):pilot.global_position=StElmoLocations.position_for(initial_spawn_id)
	_build_ui()
	interaction = AirfieldInteraction.new()
	interaction.mission = self
	add_child(interaction)
	survival=PilotSurvival.new()
	survival.mission=self
	add_child(survival)
	recovery=TransportRecovery.new()
	recovery.mission=self
	add_child(recovery)
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
	chart.home = "st_elmo" if StElmoLocations.is_fort(initial_spawn_id) else home
	chart.show_player = true
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(chart)
	var legend: Label = Label.new()
	legend.text = "WHITE: you / heading    GOLD: home    RED: enemy / GOLD ACE: ace\nMap does not pause flight. North is up; grid spacing 5 km."
	column.add_child(legend)
	var travel_row:=HBoxContainer.new()
	column.add_child(travel_row)
	travel_picker=OptionButton.new()
	for record in StElmoLocations.options():travel_picker.add_item(record.name)
	travel_row.add_child(travel_picker)
	travel_button=Button.new()
	travel_button.text="TRAVEL / SPAWN HERE (on foot)"
	travel_button.pressed.connect(func():teleport_to(StElmoLocations.options()[travel_picker.selected].id))
	travel_row.add_child(travel_button)
	chart_panel.visible = false
	aa_settings = PanelContainer.new()
	aa_settings.position = Vector2(850,270)
	aa_settings.custom_minimum_size = Vector2(350,150)
	canvas.add_child(aa_settings)
	var settings_column := VBoxContainer.new()
	aa_settings.add_child(settings_column)
	aa_sensitivity_label = Label.new()
	settings_column.add_child(aa_sensitivity_label)
	aa_sensitivity = HSlider.new()
	aa_sensitivity.min_value = .2
	aa_sensitivity.max_value = 3
	aa_sensitivity.step = .05
	aa_sensitivity.value = AAMouseControls.sensitivity
	aa_sensitivity.value_changed.connect(AAMouseControls.set_sensitivity)
	settings_column.add_child(aa_sensitivity)
	var help := Label.new()
	help.text = "Mouse aims · LMB fire · RMB sight zoom\nESC resumes · click view to recapture mouse"
	settings_column.add_child(help)
	aa_settings.hide()

func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("call_transport"):
		recovery.request()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("reset") and not survival.alive():session.call_deferred("restart_malta");get_viewport().set_input_as_handled();return
	if not survival.alive() or recovery.state in ["RETURNING","FADING_IN"]:return
	if event.is_action_pressed("navigation_map"):
		if world is CountrysideWorld:_message("Countryside test map · Malta navigation is available from Malta departures");return
		chart_panel.visible = not chart_panel.visible
		if chart_panel.visible:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("battery_command") and not get_tree().paused:
		if interaction.occupied_gun is AACommandStation:
			interaction.occupied_gun.cancel_orders()
			interaction.call_deferred("leave_gun")
			get_viewport().set_input_as_handled()
		elif interaction.nearest_command()!=null:
			interaction.call_deferred("mount_gun",interaction.nearest_command())
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("board") and not get_tree().paused:
		if is_instance_valid(occupied): call_deferred("leave_aircraft")
		else: interaction.call_deferred("interact")
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
	if not survival.alive() or recovery.state in ["RETURNING","FADING_IN"] or occupied != null or interaction.is_operating() or not pilot.active or aircraft != nearest_serviceable():
		return false
	recovery.cancel_pending()
	occupied = aircraft
	for id in world.fields:
		if world.fields[id].contains(aircraft.global_position):survival.departure_airfield=id;break
	pilot.set_active(false)
	aircraft.input_enabled = true
	aircraft.seated_pilot.visible = true
	aircraft.pilot.reset_commands()
	aircraft.pilot.automated = false
	session.attach_malta_player(aircraft)
	session.encounters.set_target(aircraft)
	_message("I starts engine · W sets throttle · taxi onto the runway")
	return true

func leave_aircraft() -> bool:
	if not is_instance_valid(occupied):
		return false
	if not survival.alive():return false
	var wreck: bool=occupied.is_destroyed or occupied.is_crashed
	if not wreck and (occupied.airspeed>maximum_exit_speed or occupied.gear.contact_count==0):
		_message("Stop on the ground before leaving")
		return false
	if not wreck and (occupied.engine_running or occupied.pilot.throttle>.01):
		_message("Reduce throttle with S and stop the engine with I before leaving")
		return false
	var exit: Vector3=safe_aircraft_exit(occupied)
	if not exit.is_finite():
		_message("No safe nearby exit yet · V requests transport while you wait for the wreck to settle")
		return false
	if wreck:last_abandoned=occupied
	occupied.input_enabled = false
	occupied.seated_pilot.visible = false
	occupied.pilot.automated = true
	occupied.pilot.reset_commands()
	occupied.pilot.brakes = true
	occupied.engine_running = false
	occupied = null
	pilot.global_position = exit
	pilot.velocity = Vector3.ZERO
	pilot.set_active(true)
	if is_instance_valid(session.hud):
		session.hud.visible = false
		session.hud.flight_input_enabled = false
	session.encounters.set_target(null)
	_message("Wreck abandoned · V call transport assistance" if wreck else "Aircraft parked; damage and fuel retained. Walk to another aircraft and press E.")
	return true

func _message(value: String) -> void:
	notice = value
	notice_time = 5

func _process(delta: float) -> void:
	travel_button.disabled=not can_travel()
	var show_settings: bool = get_tree().paused and interaction.occupied_gun != null
	if show_settings and not aa_settings.visible:aa_sensitivity.set_value_no_signal(AAMouseControls.sensitivity)
	aa_settings.visible = show_settings
	aa_sensitivity_label.text = "AA mouse sensitivity: %.2f×"%AAMouseControls.sensitivity
	chart.show_objective = is_instance_valid(session.interception) and session.interception.phase == "CHECKPOINT"
	if chart.show_objective:
		chart.objective_position = session.interception.current_checkpoint()
		chart.objective_label = "CHECKPOINT %d/%d" % [session.interception.checkpoint_index + 1, session.interception.definition.checkpoint_positions.size()]
	if not get_tree().paused:
		notice_time = maxf(notice_time - delta, 0)
	var position: Vector3 = occupied.global_position if is_instance_valid(occupied) else pilot.global_position
	var heading: Vector3 = -occupied.global_basis.z if is_instance_valid(occupied) else -Basis(Vector3.UP, pilot.yaw).z
	if interaction.occupied_gun != null:
		position = interaction.occupied_gun.global_position
		heading = -interaction.occupied_gun.muzzle.global_basis.z
	elif interaction.occupied_vehicle != null:
		position = interaction.occupied_vehicle.global_position
		heading = -interaction.occupied_vehicle.global_basis.z
	chart.player_position = position
	chart.player_heading = heading
	chart.contacts.clear()
	for foe in session.encounters.active:
		if position.distance_to(foe.global_position) < foe.ai.detection_range:
			chart.contacts.append({"position": foe.global_position, "ace": foe.encounter_ace})
	chart.show_contact = not chart.contacts.is_empty()
	if chart.show_contact:
		chart.contact_position = chart.contacts[0].position
	status.position = Vector2(32, 150) if is_instance_valid(occupied) else Vector2(32, 32)
	if is_instance_valid(occupied):
		status.text = "MALTA · %s    M Map    E Leave    I Engine %s\nFUEL %d%% · home %s" % [occupied.display_name, "ON" if occupied.engine_running else "OFF", roundi(occupied.components.fuel_remaining * 100), world.fields[home].record.name]
	else:
		status.text = interaction.prompt()
		if not interaction.is_operating():
			status.text = "WINGS OVER MALTA · ON FOOT\nWASD Walk · Arrows Turn · M Map / travel · ESC Pause · R Full restart\n" + status.text
	if get_tree().paused and not is_instance_valid(occupied):
		status.text += "\nPAUSED · ESC resumes"
	if world is CountrysideWorld:status.text=status.text.replace("MALTA ·", "COUNTRYSIDE TEST ·")
	status.text += "\nPILOT HP %d/100"%ceili(pilot.health.hp)
	if serviceable_count()==0:status.text+=" · No usable aircraft remain · pilot survival is independent"
	if notice_time > 0:
		status.text += "\n" + notice

func can_travel() -> bool:
	return not world is CountrysideWorld and occupied==null and not interaction.is_operating() and pilot.active and pilot.health.hp>0 and not get_tree().paused and not interaction.mission_ended()

func teleport_to(id: String) -> bool:
	if not can_travel():
		_message("Leave the aircraft, vehicle or AA gun before travelling on foot")
		return false
	var target: Vector3
	if StElmoLocations.is_fort(id):target=StElmoLocations.position_for(id)
	elif world.fields.has(id):target=world.fields[id].pilot_spawn
	else:return false
	# Resolve a safe floor and capsule clearance against the live world. Never
	# rebuild the session, heal, respawn enemies or move a parked aircraft.
	var space:=world.get_world_3d().direct_space_state
	var found:=false
	for offset in [Vector3.ZERO,Vector3(2,0,0),Vector3(-2,0,0),Vector3(0,0,2)]:
		var point: Vector3=target+offset
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*3,point-Vector3.UP*6,1))
		if hit.is_empty() or hit.normal.y<.7:continue
		point=hit.position+Vector3.UP*1.05
		var shape:=CapsuleShape3D.new()
		shape.height=1.8;shape.radius=.4
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=shape;query.transform=Transform3D(Basis.IDENTITY,point);query.collision_mask=31
		query.exclude=[pilot.get_rid()]
		if space.intersect_shape(query).is_empty():target=point;found=true;break
	if not found:_message("Destination obstructed; choose another spawn");return false
	recovery.cancel_pending()
	pilot.global_position=target
	pilot.velocity=Vector3.ZERO
	pilot.camera.make_current()
	chart_panel.hide()
	get_viewport().gui_release_focus()
	_message("Travel complete · aircraft, damage and the running battle preserved")
	return true

func serviceable_count(field_id: String = "") -> int:
	return fleet.filter(func(a):return is_instance_valid(a) and not a.is_destroyed and not a.is_crashed and (field_id.is_empty() or world.fields[field_id].contains(a.global_position))).size()

func clear_pilot_point(point: Vector3, exclude: Array[RID]=[]) -> Vector3:
	var space:=world.get_world_3d().direct_space_state
	var floor_query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*3,point-Vector3.UP*80,1,exclude)
	var hit:=space.intersect_ray(floor_query)
	if hit.is_empty() or hit.normal.y<.7:return Vector3.INF
	var water: bool=hit.collider.is_in_group("aircraft_water")
	var centre: Vector3=hit.position+Vector3.UP*(.5 if water else 1.05)
	var capsule:=CapsuleShape3D.new()
	capsule.height=1.9;capsule.radius=.4
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,centre);query.collision_mask=31
	var exclusions: Array[RID]=[pilot.get_rid()]
	# The sea plane intersects a swimmer's capsule by design; all other
	# live wreck, debris, aircraft, wall and gun shapes still block the exit.
	if water:exclusions.append(hit.collider.get_rid())
	query.exclude=exclusions
	if not space.intersect_shape(query).is_empty():return Vector3.INF
	return centre

func safe_aircraft_exit(aircraft: FlightAircraft) -> Vector3:
	var centre:=aircraft.global_position
	var right: Vector3=aircraft.global_basis.x*Vector3(1,0,1)
	if right.length_squared()<.01:right=Vector3.RIGHT
	right=right.normalized()
	for radius in [6.7,9.0,13.0,18.0,24.0]:
		for step in 16:
			var point: Vector3=centre+right.rotated(Vector3.UP,step*TAU/16)*radius
			if aircraft.impact_effects.water:point.y=maxf(point.y,.1)
			var exit:=clear_pilot_point(point,[aircraft.get_rid()])
			if not exit.is_finite():continue
			# Never turn leaving a high airborne wreck into ground teleportation.
			if centre.y-exit.y>8 and not aircraft.impact_effects.water:continue
			if absf(exit.y-centre.y)>20 and not aircraft.impact_effects.water:continue
			return exit
	return Vector3.INF

func safe_base_point(id: String) -> Vector3:
	if not world.fields.has(id):id=home
	var field: MaltaAirfield=world.fields[id]
	# Prefer a living replacement at this base; the original stand may now
	# be empty, obstructed by a wreck, or too far from the next fighter.
	for aircraft in fleet:
		if not is_instance_valid(aircraft) or aircraft.is_destroyed or aircraft.is_crashed or not field.contains(aircraft.global_position):continue
		for side in [1.0,-1.0]:
			var next: Vector3=aircraft.global_position+aircraft.global_basis.x*side*6.7+aircraft.global_basis.z*2
			var result:=clear_pilot_point(next)
			if result.is_finite():return result
	var base: Vector3=field.pilot_spawn
	for radius in [0.0,3.0,7.0,12.0,20.0]:
		for step in 12:
			var point: Vector3=base+Vector3(cos(step*TAU/12),0,sin(step*TAU/12))*radius
			var result:=clear_pilot_point(point)
			if result.is_finite():return result
	return Vector3.INF
