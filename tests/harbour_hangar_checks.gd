extends SceneTree
## Real interior collision/camera regression; no camera pose is forced.
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print("PASS: " if ok else "FAIL: ", label)
func sea_impact(aircraft: FlightAircraft) -> void:
	aircraft.request_reset()
	aircraft.pending_reset_pose = Transform3D(Basis.IDENTITY, Vector3(50000, 4, 50000))
	aircraft.pending_reset_velocity = Vector3(0, -3, 0)
	for tick in 600:
		await physics_frame
		if aircraft.impact_effects.water: break
	await frames(5)
func run() -> void:
	GameAudioMixer.instance.playback_enabled = false
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_harbour()
	await frames(180)
	var mission: MaltaMission = game.malta_mission
	var field: MaltaAirfield = mission.world.fields.hal_far
	var hangar: AircraftHangar = field.installations[0]
	var local_fleet: Array = mission.fleet.filter(func(a): return field.contains(a.global_position))
	check(local_fleet.size() == 3 and local_fleet.all(func(a): return a is SeaGladiator), "Home hangar contains three player-available Gladiators and no Spitfire")
	check(mission.fleet.size() == 7 and mission.world.fields.hal_far.record.stationed_aircraft == ["spitfire", "sea_gladiator"], "Mission roster leaves shared airfield data and other bases intact")
	check(local_fleet.all(func(a): return a.health.hp == 100 and not a.engine_running and a.gear.contact_count > 0), "All three Gladiators settle serviceably on separate interior stands")
	check(game.harbour.wingmen.size() == 2 and game.harbour.wingmen.all(func(a): return a.ai.takeoff_hold), "Existing Hope and Charity wingmen keep their takeoff behaviour")
	for aircraft in local_fleet:
		mission.pilot.global_position = aircraft.global_position + aircraft.global_basis.x * 6.7
		await frames(3)
		check(mission.board_nearest() and mission.occupied == aircraft, "Board each hangar Gladiator through the existing interaction")
		var inside := true
		for tick in 120:
			await physics_frame
			var eye: Vector3 = hangar.to_local(game.chase.global_position)
			inside = inside and absf(eye.x) < hangar.width * .5 and absf(eye.z) < hangar.depth * .5 and eye.y < hangar.eaves_height and eye.y > hangar.floor_height(eye.x, eye.z)
		check(inside, "Chase camera stays below roof and inside hangar for every settled boarding frame")
		check(game.chase.global_position.distance_to(aircraft.global_position) > 3, "Interior camera retains a useful view behind the aircraft")
		if DisplayServer.get_name() != "headless" and aircraft == mission.initial_aircraft:
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/harbour-boarding-camera.png")
		check(mission.leave_aircraft() and mission.pilot.camera.current, "Dismount restores walking camera without moving or repairing aircraft")
	game.restart_malta()
	await frames(180)
	check(game.malta_mission.fleet.size() == 7 and game.malta_mission.fleet.filter(func(a): return game.field.fields.hal_far.contains(a.global_position)).size() == 3, "Retry recreates exactly the mission roster without duplicates")
	mission = game.malta_mission
	var spare: FlightAircraft = mission.fleet.filter(func(a): return a != mission.initial_aircraft)[0]
	await sea_impact(spare)
	check(spare.impact_effects.water and not game.harbour.is_finished(), "An unoccupied aircraft hitting water does not fail the player's mission")
	check(mission.board_nearest(), "Board Faith for a real water-surface crash fixture")
	await sea_impact(mission.occupied)
	check(mission.occupied.impact_effects.water and mission.survival.alive() and game.harbour.phase == "FAILED", "Even a survivable sea crash immediately fails this harbour mission")
	check(game.harbour.final_reason.contains("lost at sea") and game.harbour.result_count == 1, "Sea failure gives a specific reason and exactly one result")
	await frames(120)
	check(game.harbour.result_count == 1 and game.encounters.active.is_empty(), "Sinking cannot repeat results or start enemy waves")
	game.restart_malta()
	await frames(180)
	check(not game.harbour.player_sea_crash and game.harbour.phase == "TAKEOFF" and game.harbour.result_count == 0, "Retry clears the sea-loss latch and mission outcome")
	game.show_selection(false)
	game.start_free_roam("spitfire")
	await frames(180)
	check(game.malta_mission.fleet.size() == 9 and game.malta_mission.fleet.filter(func(a): return a is SeaGladiator).size() == 3, "Ordinary free roam retains its mixed fleet including the Hurricane")
	game.queue_free()
	await frames(10)
	print("HARBOUR HANGAR RESULT: ", passed, "/", passed + failed, " passed")
	quit(0 if failed == 0 else 1)
