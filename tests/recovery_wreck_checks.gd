extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await physics_frame
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failed+=1
	print("PASS: " if ok else "FAIL: ",label)
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.start_free_roam("spitfire");await frames(180)
	var mission: MaltaMission=game.malta_mission
	check(mission.board_nearest(),"Board inside selected hangar")
	var aircraft: FlightAircraft=mission.occupied
	var field: MaltaAirfield=mission.world.fields.ta_qali
	aircraft.request_reset();aircraft.pending_reset_pose=Transform3D(Basis(Vector3.FORWARD,PI),field.to_global(Vector3(-100,2,50)))
	await frames(5)
	aircraft.take_damage(1000)
	await frames(10)
	check(mission.survival.alive() and mission.leave_aircraft(),"Survivor can leave an overturned disabled aircraft")
	var capsule:=CapsuleShape3D.new();capsule.height=1.9;capsule.radius=.4
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,mission.pilot.global_position);query.collision_mask=31;query.exclude=[mission.pilot.get_rid()]
	check(mission.world.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"Overturned exit capsule clears live wreck, terrain and nearby structures")
	# Explicit unoccupied breakup fixture: retain damage presentation without
	# applying a fictitious crash injury to an already exited player.
	aircraft.impact_effects.start()
	await frames(1700)
	check(aircraft.is_destroyed and aircraft.health.hp==0 and not game.encounters.ended,"Leaving never resurrects a wreck or ends a live-pilot attempt")
	check(aircraft.impact_effects.persistent_remnant!=null and get_nodes_in_group("persistent_aircraft_wrecks").size()==1,"Central wreckage remains after dynamic fragment expiry")
	check(aircraft.impact_effects.persistent_remnant.get_child_count()>0 and aircraft.impact_effects.persistent_remnant.get_child_count()<=64,"Persistent wreck detail has a bounded mesh count and no endless emitter")
	var departure: String=mission.survival.departure_airfield
	mission.recovery.request();game.restart_malta();await frames(180)
	check(game.malta_mission.recovery.state=="IDLE" and game.field.trucks.size()==3 and get_nodes_in_group("persistent_aircraft_wrecks").is_empty(),"Full retry removes request, temporary transport and persistent wreckage")
	check(game.malta_mission.pilot.health.hp==100 and game.malta_mission.fleet.all(func(a):return a.health.hp==100),"Only a full retry restores the pilot and fleet")
	# Boarding at a different airfield records that field, not the original menu home.
	mission=game.malta_mission
	mission.pilot.global_position=mission.world.fields.luqa.pilot_spawn
	await frames(3)
	check(mission.board_nearest() and mission.survival.departure_airfield=="luqa" and departure=="ta_qali","Recovery destination follows the airfield where the current aircraft was taken")
	mission.occupied.take_damage(1000)
	await frames(3)
	check(mission.leave_aircraft(),"Exit at a different base for stale-pickup cancellation test")
	mission.recovery.response_seconds=.02;mission.recovery.request()
	for i in 1200:
		await physics_frame
		if mission.recovery.state=="READY":break
	check(mission.teleport_to("ta_qali") and mission.recovery.state=="IDLE" and mission.world.trucks.size()==3,"Existing map travel cancels stale pickup so future recovery is not blocked")
	game.show_selection(false);game.show_malta_selection()
	game.malta_menu.select_field("hal_far");game.malta_menu.selected_kind="sea_gladiator"
	game._return_from_malta_options()
	game.start_free_roam(game.selected_aircraft)
	await frames(180)
	check(game.home_airfield=="hal_far" and game.aircraft is SeaGladiator and game.malta_mission.pilot.active,"Main free roam remembers airfield/aircraft options even when returning from submenu without departing")
	for plane in game.malta_mission.fleet:plane.take_damage(1000)
	await frames(5)
	check(game.malta_mission.survival.alive() and game.malta_mission.serviceable_count()==0 and game.malta_mission.status.text.contains("No usable aircraft"),"No aircraft left is explained without falsely killing the surviving pilot")
	game.queue_free();await frames(10)
	print("RECOVERY WRECK RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)
