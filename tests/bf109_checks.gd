extends SceneTree

var checks: int = 0
var failures: int = 0
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count: await physics_frame

func check(result: bool, description: String) -> void:
	checks += 1
	if not result: failures += 1
	print(("PASS: " if result else "FAIL: ") + description)

func shift(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SHIFT
	event.keycode = KEY_SHIFT
	event.pressed = pressed
	Input.parse_input_event(event)

func land_fixture(plane: Bf109, field: MaltaAirfield) -> bool:
	plane.request_reset()
	plane.pending_reset_pose = Transform3D(field.global_basis * Basis(Vector3.RIGHT, .10), field.to_global(Vector3(0,1.7,-100)))
	plane.pending_reset_velocity = -field.global_basis.z * 34 - Vector3.UP * 1.6
	await frames(2)
	plane.pilot.automated = true
	plane.engine_running = false
	plane.pilot.brakes = true
	for i in 240:
		await physics_frame
		if plane.gear.contact_count >= 2:
			return not plane.is_crashed
	return false

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.show_malta_selection()
	var menu: MaltaDepartureMenu = game.malta_menu
	menu.fighter_picker.select(menu._kinds().find(Bf109.EMIL))
	menu._choose_kind(menu.fighter_picker.selected)
	menu.depart()
	await frames(15)
	var mission: MaltaMission = game.malta_mission
	if not is_instance_valid(mission) or not mission.occupied is Bf109:
		check(false, "German option launches an occupied aircraft")
		quit(1)
		return
	var emil := mission.occupied as Bf109
	var sortie := mission.free_roam_aircraft
	var emodel := emil.model as Bf109Model
	check(emil.variant == Bf109.EMIL and emil.engine_running and emil.airspeed > 55 and not emil.gear.extended and emil.altitude > 300, "Emil menu uses a clean powered airborne start")
	check(emodel.find_child("StabilizerBraceLeft", true, false) != null and emodel.cannon_ports.size() == 2, "Emil has its braced tail and two wing cannon ports")
	check(emil.guns.remaining_by_port == [1000, 1000] and emil.cannon.remaining_by_port == [60, 60], "Emil MG and wing cannon magazines are separate")
	Input.action_press("fire")
	await frames(25)
	Input.action_release("fire")
	check(emil.guns.remaining_by_port[0] < 1000 and emil.cannon.remaining_by_port[0] < 60 and emil.cannon.remaining_by_port[1] < 60, "Emil fires its cowling and both wing batteries")
	check(not emil.devices.command_airbrakes(true) and emil.devices.status().ends_with("N/A"), "Emil does not have dedicated airbrakes")

	emil.airspeed = 52
	Input.action_press("flaps")
	await frames(110)
	Input.action_release("flaps")
	var fraction := emil.devices.flaps
	var angle := emodel.flap_hinges[0].rotation.x
	await frames(65)
	check(fraction > 0.05 and fraction < 0.3 and is_equal_approx(fraction, emil.devices.flaps) and is_equal_approx(angle, deg_to_rad(emil.flap_landing_degrees) * fraction), "Hold Q deploys a visible partial flap setting and releasing holds it")
	shift(true)
	Input.action_press("flaps")
	await frames(60)
	Input.action_release("flaps")
	shift(false)
	check(emil.devices.flaps < fraction, "Shift+Q retracts with priority")
	emil.advance_airframe(1, Vector3(0, -19, -48), Vector3.ZERO)
	check(emil.slats.x > 0.9 and emil.slats.y > 0.9 and emil.slat_stall_bonus > 0 and emil.slat_lift_bonus > 0, "High local incidence deploys automatic slats and changes lift and stall behaviour")
	emil.advance_airframe(1, Vector3(0, 0, -60), Vector3.ZERO)
	check(emil.slats.is_zero_approx(), "Slats close at low incidence while the flap setting is unchanged")
	var manual := emil.radiator
	Input.action_press("radiator_open")
	emil.advance_airframe(1, Vector3(0, 0, -55), Vector3.ZERO)
	Input.action_release("radiator_open")
	check(emil.radiator > manual and emil.cooling_drag > .008, "Emil manual shutters move and add drag independently")

	var world_id: int = mission.world.get_instance_id()
	sortie.kind_picker.select(sortie.kinds.find(Bf109.FRIEDRICH))
	sortie.placement.select(0)
	var button := sortie.spawn_button
	button.pressed.emit()
	button.pressed.emit()
	await frames(10)
	var friedrich := sortie.spawned[1] as Bf109
	var copy := sortie.spawned[2] as Bf109
	check(sortie.spawned.size() == 3 and mission.occupied == emil and mission.world.get_instance_id() == world_id, "Two deliberate button presses add two aircraft and keep the current session and controller")
	check(friedrich.name != copy.name and friedrich.global_position.distance_to(copy.global_position) > 230, "Duplicate Friedrichs have unique names and separated air starts")
	check(friedrich.pilot.automated and copy.pilot.automated and friedrich.airspeed > 45, "Unoccupied airborne aircraft use flight control")
	var fmodel := friedrich.model as Bf109Model
	check(fmodel.find_child("StabilizerBraceLeft", true, false) == null and fmodel.cannon_ports.size() == 1 and absf(fmodel.cannon_ports[0].position.x) < 0.01, "Friedrich has an unbraced tail and centreline hub cannon")
	check(friedrich.mass > emil.mass and friedrich.engine_thrust > emil.engine_thrust and friedrich.parasite_drag < emil.parasite_drag and not friedrich.devices.command_airbrakes(true), "Variant forces, handling, and airbrake availability are configured")
	friedrich.coolant = 0.9
	friedrich.advance_airframe(0.2, Vector3(0, 0, -55), Vector3.ZERO)
	check(friedrich.radiator > .65 and friedrich.devices.flaps == 0, "Friedrich automatic cooling responds independently of landing flaps")
	check(sortie.take_control(friedrich) and game.chase.aircraft == friedrich and game.hud.aircraft == friedrich and not emil.input_enabled and emil.pilot.automated and friedrich.input_enabled, "Transfer moves camera, HUD and exactly one input owner")
	Input.action_release("fire")
	await frames(3)
	Input.action_press("fire")
	await frames(40)
	Input.action_release("fire")
	check(friedrich.guns.remaining_by_port[0] < 500 and friedrich.cannon.remaining_by_port[0] < 200 and copy.cannon.remaining_by_port == [200], "Both batteries fire and magazines are independent")
	friedrich.take_damage(27)
	friedrich.components.fuel_remaining = 0.43
	friedrich.devices.flaps = 0.32
	check(friedrich.health.hp == 73 and copy.health.hp == 100 and copy.devices.flaps == 0.0 and copy.components.fuel_remaining > 0.9, "Health, fuel and flap position are independent across copies")

	var parked := sortie.spawn(Bf109.EMIL, false)
	await frames(160)
	check(parked != null and parked.gear.contact_count >= 2 and not parked.engine_running and parked.pilot.brakes and parked.airspeed < 2, "Compatible clear parking stand produces a stationary, boardable Emil")
	var field: MaltaAirfield = mission.world.fields.ta_qali
	sortie.stop_standby(copy)
	check(await land_fixture(copy, field), "Friedrich suspension accepts a controlled runway touchdown")
	sortie.stop_standby(emil)
	check(await land_fixture(emil, field), "Emil suspension accepts a controlled runway touchdown")
	friedrich.take_damage(1000)
	friedrich.impact_effects.ground_contact(Vector3(35,-48,-105), Vector3.UP)
	await frames(8)
	check(friedrich.is_destroyed and friedrich.impact_effects.started and not friedrich.impact_effects.fragments.is_empty() and not copy.is_destroyed, "Shared ground breakup fragments only the destroyed aircraft")
	var old_id := emil.get_instance_id()
	game.restart_malta()
	await frames(12)
	mission = game.malta_mission
	check(mission.world.get_instance_id() != world_id and mission.free_roam_aircraft.spawned.size() == 1 and not is_instance_id_valid(old_id) and mission.occupied is Bf109 and mission.occupied.health.hp == 100, "Restart drops previous aircraft and reconstructs the selected healthy Emil")
	game.show_selection(false)
	game.start_malta("luqa", Bf109.FRIEDRICH, "encounter", false, false)
	await frames(155)
	mission = game.malta_mission
	var parked_start := mission.initial_aircraft as Bf109
	check(parked_start != null and mission.pilot.active and mission.occupied == null and not parked_start.engine_running, "Parked Friedrich start puts the player on foot with the engine off")
	check(mission.board_nearest() and mission.occupied == parked_start and game.chase.aircraft == parked_start, "Existing nearby boarding takes control of the parked Friedrich")
	print("BF 109 RESULT: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
