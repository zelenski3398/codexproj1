extends SceneTree

var failures := 0
var host: SubViewport
var duel: DuelRound
var result: Array
var result_count := 0
var cancellation := ""

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in count: await physics_frame

func check(condition: bool, description: String) -> void:
	if not condition: failures += 1
	print(("PASS " if condition else "FAIL ") + description)

func fresh() -> void:
	if is_instance_valid(host):
		host.queue_free()
		await frames(4)
	host = SubViewport.new()
	host.own_world_3d = true
	host.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(host)
	duel = DuelRound.new()
	host.add_child(duel)
	result = []
	result_count = 0
	cancellation = ""
	duel.completed.connect(func(winner, reason, forfeits, kills):
		result = [winner, reason, forfeits, kills]
		result_count += 1)
	duel.preparation_cancelled.connect(func(reason): cancellation = reason)
	duel.round_id = "fixture-round"
	duel.setup(["spitfire", "bf109_e4"], {"load_seconds":30, "prep_seconds":180, "combat_seconds":25,
		"boundary_seconds":.12, "reconnect_seconds":.12, "credit_seconds":12,
		"mutual_seconds":.45, "waypoint_radius":600, "waypoint_altitude":130})
	await frames(8)

func park(plane: FlightAircraft, at: Vector3, facing: Vector3 = Vector3.FORWARD) -> void:
	plane.freeze = true
	plane.global_transform = Transform3D(Basis.looking_at(facing), at)

func prepare() -> void:
	duel.loaded = [true, true]
	await frames(5)

func combat() -> void:
	await prepare()
	for slot in 2: park(duel.planes[slot], DuelAircraft.WAYPOINTS[slot])
	await frames(5)

func run() -> void:
	GameAudioMixer.instance.playback_enabled = false
	await fresh()
	var a := duel.planes[0]
	var b := duel.planes[1]
	check(not is_instance_valid(duel.world.aa_battery) and not is_instance_valid(duel.world.fort_battery),
		"No airfield or fort AA in the authority physics world")
	check(a.gear.extended and a.engine_running and a.global_position.y < 150 and b.global_position.y > 450,
		"Allies spawn on the runway and Axis spawns over the sea")
	duel.loaded[0] = true
	await frames(4)
	check(duel.phase == "loading", "One client cannot start the clock")
	await prepare()
	check(duel.phase == "preparation" and duel.deadline - duel.elapsed > 179 and b.linear_velocity.length() > 55,
		"Both clients start the shared prep clock with the Axis fighter in flight")
	duel.control(0, {"seq":1,"axes":[0,0,0,0],"fire":true})
	await frames(8)
	check(a.guns.pool.total_spawned == 0, "Prep rejects weapons")
	park(a, DuelAircraft.WAYPOINTS[0])
	await frames(3)
	park(a, DuelAircraft.WAYPOINTS[0] + Vector3(800, 0, 0))
	await frames(3)
	check(duel.arrived == [true, false], "A reached waypoint stays latched after departing its radius")
	a.is_crashed = true
	await frames(3)
	check(not duel.arrived[0], "A crash clears remembered arrival")
	a.freeze = false
	duel.reset_player(0)
	await frames(6)
	check(not a.is_crashed and not a.reset_pending and duel.deadline - duel.elapsed < 180,
		"Prep reset restarts the plane without restarting the clock")
	park(a, DuelAircraft.WAYPOINTS[0])
	await frames(3)
	park(b, DuelAircraft.WAYPOINTS[1])
	await frames(3)
	check(duel.phase == "combat" and a.health.hp == a.health.max_hp and b.health.hp == b.health.max_hp
		and a.global_position.distance_to(DuelAircraft.WAYPOINTS[0]) < 1, "Both arrivals start combat once without moving the planes")
	var point := Vector3(5400, 480, -2800)
	park(a, point + Vector3(0,0,45), Vector3.FORWARD)
	park(b, point - Vector3(0,0,45), Vector3.BACK)
	for seq in range(2, 14):
		duel.control(0, {"seq":seq,"axes":[0,0,0,0],"fire":true})
		duel.control(1, {"seq":seq,"axes":[0,0,0,0],"fire":true})
		await frames(7)
		if a.health.hp < a.health.max_hp and b.health.hp < b.health.max_hp: break
	check(a.health.hp < a.health.max_hp and b.health.hp < b.health.max_hp,
		"Both real gun batteries deal swept projectile damage inside the authority world")
	a.is_crashed = true
	await frames(7)
	b.is_crashed = true
	await frames(65)
	check(result_count == 1 and result[0] == -1 and result[3] == [true,true],
		"Mutual loss is a draw and recent reciprocal damage credits both exact fighters")
	var hits := duel.recent_hits.map(func(hit): return hit.id)
	check(hits.size() >= 2 and hits.size() == Array(hits).reduce(func(unique, value):
		unique[value] = true
		return unique, {}).size(), "Authority assigns distinct identifiers to recent damage events")
	var total := a.health.hp + b.health.hp
	await frames(30)
	check(result_count == 1 and total == a.health.hp + b.health.hp, "Final result stops further damage and cannot repeat")
	await fresh()
	await combat()
	park(duel.planes[1], DuelAircraft.CENTRE + Vector3(DuelAircraft.BOUNDARY + 100, 300, 0))
	await frames(3)
	check(duel.outside[1] >= 0, "Crossing the boundary starts a warning")
	park(duel.planes[1], DuelAircraft.WAYPOINTS[1])
	await frames(3)
	check(duel.outside[1] < 0, "Returning inside clears the boundary warning")
	park(duel.planes[1], DuelAircraft.CENTRE + Vector3(DuelAircraft.BOUNDARY + 100, 300, 0))
	await frames(85)
	check(result_count == 1 and result[0] == 0 and result[2][1] and result[3] == [false,false],
		"Boundary expiry records a forfeit without a kill")
	await fresh()
	await combat()
	duel.set_connected(0, false)
	await frames(85)
	check(result_count == 1 and result[0] == 1 and result[2][0], "Expired reconnect grace forfeits combat")
	await fresh()
	await prepare()
	duel.set_connected(0, false)
	check(not cancellation.is_empty() and result_count == 0, "Preparation disconnect cancels without recording a result")
	await fresh()
	await prepare()
	duel.deadline = duel.elapsed + .05
	await frames(10)
	check(not cancellation.is_empty() and result_count == 0, "Preparation timeout cancels without awarding stats")
	var path := "user://duel-check-" + Crypto.new().generate_random_bytes(8).hex_encode() + ".json"
	var store := DuelStore.new(path)
	var one := store.create("Wing One")
	var two := store.create("Wing Two")
	var pair := [one.id, two.id]
	var aircraft := ["spitfire", "bf109_e4"]
	check(store.record("persistent-round", pair, aircraft, 0, [false,false], [true,false], "Kill")
		and store.record("persistent-round", pair, aircraft, 0, [false,false], [true,false], "Duplicate"),
		"Career storage accepts a result once and treats duplicates idempotently")
	var restored := DuelStore.new(path)
	var career: Dictionary = restored.data.profiles[one.id].stats
	check(restored.authorize(one.id, one.token) and not restored.authorize(one.id, two.token)
		and career.wins == 1 and career.kills == 1 and career.aircraft.spitfire == 1
		and restored.data.results["persistent-round"].kills[0].defeated == "bf109_e4",
		"Reloaded store restores authentication, one career award and the defeated variant")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	host.queue_free()
	await frames(6)
	quit(1 if failures else 0)
