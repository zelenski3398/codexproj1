class_name FreeRoamAircraft
extends Node

const AIR_SEPARATION := 240.0
const GROUND_SEPARATION := 10.5
const AIR_CLEARANCE := 350.0

var mission: MaltaMission
var serial: int = 0
var spawned: Array[FlightAircraft] = []
var air_controllers: Dictionary = {}
var panel: PanelContainer
var kind_picker: OptionButton
var placement: OptionButton
var spawn_button: Button
var transfer_picker: OptionButton
var transfer_button: Button
var kinds: Array[String] = ["spitfire", "sea_gladiator", "hurricane", Bf109.EMIL, Bf109.FRIEDRICH]

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 19
	add_child(layer)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -160
	panel.offset_right = 160
	layer.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(stack)
	var title := Label.new()
	title.text = "FREE ROAM AIRCRAFT"
	stack.add_child(title)
	kind_picker = OptionButton.new()
	for kind in kinds:
		kind_picker.add_item(("German · " + Bf109.title(kind)) if kind in Bf109.KINDS else AlliedAircraft.title(kind))
	stack.add_child(kind_picker)
	placement = OptionButton.new()
	placement.add_item("Airborne")
	placement.add_item("Parked at home airfield")
	stack.add_child(placement)
	spawn_button = Button.new()
	spawn_button.text = "Spawn another aircraft"
	stack.add_child(spawn_button)
	spawn_button.pressed.connect(_spawn_requested)
	stack.add_child(HSeparator.new())
	transfer_picker = OptionButton.new()
	stack.add_child(transfer_picker)
	transfer_button = Button.new()
	transfer_button.text = "Take control in flight"
	transfer_button.pressed.connect(_transfer_requested)
	stack.add_child(transfer_button)
	var hint := Label.new()
	hint.text = "Use E to board parked aircraft nearby."
	stack.add_child(hint)
	var close_button := Button.new()
	close_button.text = "Close · P"
	close_button.pressed.connect(_close)
	stack.add_child(close_button)
	panel.hide()

func _input(event: InputEvent) -> void:
	if GameplayHUD.blocks_input() or get_tree().paused or event.is_echo(): return
	if event.is_action_pressed("aircraft_spawner"):
		if panel.visible: _close()
		else:
			_refresh_transfers()
			panel.show()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif panel.visible and event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	panel.hide()
	get_viewport().gui_release_focus()

func _spawn_requested() -> void:
	spawn(kinds[kind_picker.selected], placement.selected == 0)
	_refresh_transfers()

func _transfer_requested() -> void:
	var selection := transfer_picker.selected
	if selection >= 0:
		var plane := instance_from_id(int(transfer_picker.get_item_metadata(selection))) as FlightAircraft
		if take_control(plane): _close()

func _refresh_transfers() -> void:
	transfer_picker.clear()
	for plane in air_controllers:
		if not _can_transfer(plane): continue
		transfer_picker.add_item("%s · %s" % [plane.display_name, plane.name])
		transfer_picker.set_item_metadata(transfer_picker.item_count - 1, plane.get_instance_id())
	transfer_button.disabled = transfer_picker.item_count == 0

func spawn(kind: String, airborne: bool, initial: bool = false) -> FlightAircraft:
	if kind not in kinds or not mission.survival.alive(): return null
	var pose := _airborne_pose(initial) if airborne else _parking_pose()
	if not pose.origin.is_finite():
		mission._message("No safe aircraft spawn available")
		return null
	var plane: FlightAircraft
	if kind in Bf109.KINDS:
		var fighter := Bf109.new()
		fighter.variant = kind
		plane = fighter
	else:
		plane = AlliedAircraft.create(kind)
	serial += 1
	plane.name = "Aircraft_%03d" % serial
	plane.process_mode = Node.PROCESS_MODE_PAUSABLE
	plane.reset_position = pose.origin
	plane.engine_running = airborne
	plane.input_enabled = false
	plane.fuel_consumption_rate = 1.0 / 7200.0
	mission.add_child(plane)
	plane.global_transform = pose
	plane.collision_mask = 7
	plane.impact_effects.preserve_wreck_remains = true
	mission.fleet.append(plane)
	spawned.append(plane)
	mission.survival.track_aircraft(plane)
	standby(plane, airborne)
	if airborne:
		plane.request_reset()
		plane.pending_reset_pose = pose
		plane.pending_reset_velocity = -pose.basis.z * 65.0
		plane.reset_completed.connect(func():
			plane.gear.extended = false
			plane.model.gear_mix = 0.0
			plane.pilot.throttle = 0.77
		, CONNECT_ONE_SHOT)
	if initial:
		mission.initial_aircraft = plane
		if airborne: _claim(plane)
		else:
			mission.pilot.global_position = pose.origin + pose.basis.x * 5.5
			mission.pilot.yaw = atan2(pose.basis.z.x, pose.basis.z.z)
	else:
		mission._message("%s added %s" % [plane.display_name, "in flight" if airborne else "at " + mission.world.fields[mission.home].record.name])
	return plane

func standby(plane: FlightAircraft, airborne: bool) -> void:
	plane.input_enabled = false
	plane.pilot.automated = true
	var previous_power := plane.pilot.throttle
	plane.pilot.reset_commands()
	if airborne: plane.pilot.throttle = previous_power
	plane.pilot.brakes = not airborne
	if not airborne:
		stop_standby(plane)
		plane.engine_running = false
		return
	var controller: EnemyPilot = air_controllers.get(plane)
	if controller == null:
		controller = EnemyPilot.new()
		controller.name = "FreeRoamOrbit"
		controller.aircraft = plane
		controller.combat_enabled = false
		controller.measured_terrain = true
		controller.world_extent = INF
		controller.cruise_speed = 62
		controller.minimum_agl = 180
		plane.add_child(controller)
		air_controllers[plane] = controller
	controller.patrol_center = plane.global_position
	controller.set_physics_process(true)

func stop_standby(plane: FlightAircraft) -> void:
	if air_controllers.has(plane): air_controllers[plane].set_physics_process(false)

func _can_transfer(plane: FlightAircraft) -> bool:
	var current := mission.occupied
	return is_instance_valid(current) and is_instance_valid(plane) and current != plane and not plane.is_destroyed and not plane.is_crashed and not plane.reset_pending and not current.is_destroyed and not current.is_crashed and current.altitude > 45 and plane.altitude > 45

func take_control(plane: FlightAircraft) -> bool:
	if not _can_transfer(plane):
		mission._message("Airborne transfer requires two serviceable aircraft in flight")
		return false
	var previous := mission.occupied
	previous.seated_pilot.hide()
	standby(previous, true)
	_claim(plane)
	return true

func _claim(plane: FlightAircraft) -> void:
	stop_standby(plane)
	mission.occupied = plane
	mission.pilot.set_active(false)
	plane.input_enabled = true
	plane.pilot.automated = false
	plane.seated_pilot.show()
	mission.session.attach_malta_player(plane)
	mission.session.encounters.set_target(plane)

func _parking_pose() -> Transform3D:
	var field: MaltaAirfield = mission.world.fields[mission.home]
	for pose in field.parking:
		if not _separated(pose.origin, GROUND_SEPARATION): continue
		var volume := BoxShape3D.new()
		volume.size = Vector3(9.9, 1.0, 8.8)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = volume
		query.transform = pose.translated(Vector3.UP * 0.7)
		query.collision_mask = 15
		if field.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return pose
	return Transform3D(Basis.IDENTITY, Vector3.INF)

func _airborne_pose(initial: bool) -> Transform3D:
	var field: MaltaAirfield = mission.world.fields[mission.home]
	var anchor := mission.occupied.global_position if is_instance_valid(mission.occupied) else field.global_position
	var space := mission.world.get_world_3d().direct_space_state
	for i in range(24):
		var angle: float = TAU * fposmod((serial + i) * 0.381966, 1.0)
		var radius := 580.0 + 210.0 * floorf(i / 6.0)
		var offset := Vector3(cos(angle), 0, sin(angle)) * radius
		var point := anchor + offset
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 12000, point.z), Vector3(point.x, -10, point.z), 1)
		var hit := space.intersect_ray(query)
		var terrain_y := float(hit.position.y) if not hit.is_empty() else 0.0
		point.y = maxf(maxf(terrain_y + AIR_CLEARANCE, 550.0), anchor.y + (120 if not initial else 0))
		if not _separated(point, AIR_SEPARATION): continue
		var facing := (anchor - point).slide(Vector3.UP).normalized()
		return Transform3D(Basis.looking_at(facing, Vector3.UP), point)
	return Transform3D(Basis.IDENTITY, Vector3.INF)

func _separated(point: Vector3, distance: float) -> bool:
	for aircraft in get_tree().get_nodes_in_group("combat_aircraft"):
		if not is_instance_valid(aircraft): continue
		var current: Vector3 = aircraft.pending_reset_pose.origin if aircraft.reset_pending else aircraft.global_position
		if current.distance_squared_to(point) < distance * distance: return false
	return true
