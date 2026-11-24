class_name DuelRound
extends Node3D

signal completed(winner: int, reason: String, forfeits: Array, kills: Array)
signal preparation_cancelled(reason: String)
var config: Dictionary
var world: MaltaWorld
var planes: Array[FlightAircraft] = []
var arrived := [false, false]
var loaded := [false, false]
var disconnected := [-1.0, -1.0]
var outside := [-1.0, -1.0]
var losses := [false, false]
var forfeits := [false, false]
var kills := [false, false]
var inputs := [{}, {}]
var sequences := [-1, -1]
var command_at := [-1.0, -1.0]
var elapsed := 0.0
var deadline := 0.0
var resolution := -1.0
var reason := ""
var phase := "loading"
var serial := 0
var round_id := ""
var flight_lives := [1, 1]
var hit_serial := 0
var recent_hits: Array[Dictionary] = []


func setup(kinds: Array, rules: Dictionary) -> void:
	config = rules
	world = MaltaWorld.new()
	world.duel_only = true
	add_child(world)
	for side in 2:
		var plane := DuelAircraft.make(self, kinds[side], side)
		planes.append(plane)
		for gun in DuelAircraft.batteries(plane):
			gun.pool.damage_confirmed.connect(_record_hit.bind(side))
		DuelAircraft.spawn(plane, world, side)
		plane.reset_completed.connect(func():
			if phase == "loading": plane.freeze = true
		, CONNECT_ONE_SHOT)
	deadline = config.load_seconds


func control(side: int, packet: Dictionary) -> void:
	if phase not in ["preparation", "combat"]: return
	var seq: Variant = packet.get("seq")
	if seq is not float and seq is not int: return
	if not is_finite(float(seq)) or seq != floorf(float(seq)) or seq <= sequences[side] or seq > 2147483647: return
	if elapsed - command_at[side] < .012: return
	var axes: Variant = packet.get("axes")
	if axes is not Array or axes.size() != 4: return
	for value in axes:
		if (value is not int and value is not float) or not is_finite(float(value)) or absf(float(value)) > 1.0: return
	sequences[side] = int(seq)
	command_at[side] = elapsed
	inputs[side] = packet


func reset_player(side: int) -> void:
	if phase != "preparation" or not _lost(side): return
	inputs[side] = {}
	arrived[side] = false
	flight_lives[side] += 1
	DuelAircraft.spawn(planes[side], world, side)


func set_connected(side: int, connected: bool) -> void:
	if connected:
		disconnected[side] = -1.0
		inputs[side] = {}
		sequences[side] = -1
		command_at[side] = -1.0
	elif phase in ["preparation", "loading"]:
		cancel("Opponent disconnected during preparation.")
	elif phase == "combat" and disconnected[side] < 0:
		disconnected[side] = elapsed + config.reconnect_seconds
		inputs[side] = {}


func leave(side: int) -> void:
	if phase == "combat": _lose(side, "A player left the duel.", true)
	elif phase in ["preparation", "loading"]: cancel("A player left before combat.")


func cancel(message: String) -> void:
	if phase not in ["loading", "preparation"]: return
	phase = "cancelled"
	preparation_cancelled.emit(message)


func _physics_process(delta: float) -> void:
	if planes.size() != 2 or phase in ["results", "cancelled"]: return
	elapsed += delta
	if phase == "loading":
		if not planes.any(func(plane): return plane.reset_pending) and loaded[0] and loaded[1]:
			phase = "preparation"
			deadline = elapsed + config.prep_seconds
			for plane in planes:
				plane.freeze = false
				plane.linear_velocity = plane.pending_reset_velocity
		elif elapsed >= deadline:
			cancel("A client did not finish loading.")
		return
	for side in 2: _apply(side, delta)
	if phase == "preparation":
		for side in 2:
			var point := planes[side].global_position
			var offset: Vector3 = point - DuelAircraft.WAYPOINTS[side]
			if _lost(side) or planes[side].reset_pending:
				arrived[side] = false
			elif Vector2(offset.x, offset.z).length() <= config.waypoint_radius and absf(offset.y) <= config.waypoint_altitude:
				arrived[side] = true
		if elapsed >= deadline:
			cancel("Preparation expired before both fighters reached their rendezvous.")
		elif arrived[0] and arrived[1]:
			_start_combat()
		return
	for side in 2:
		if _lost(side):
			_lose(side, "Aircraft lost.", false)
		elif disconnected[side] >= 0 and elapsed >= disconnected[side]:
			_lose(side, "Reconnect grace period expired.", true)
		else:
			_boundary(side)
	if resolution >= 0 and elapsed >= resolution:
		var winner := -1 if losses[0] and losses[1] else (1 if losses[0] else 0)
		_finish(winner, "Both aircraft were lost." if winner < 0 and not forfeits[0] and not forfeits[1] else reason)
	elif resolution < 0 and elapsed >= deadline:
		_finish(-1, "Combat time expired.")


func _apply(side: int, delta: float) -> void:
	var plane := planes[side]
	if plane.reset_pending: return
	var packet: Dictionary = inputs[side] if elapsed - command_at[side] < .4 else {}
	var axes: Array = packet.get("axes", [0, 0, 0, 0])
	plane.pilot.pitch = axes[0]
	plane.pilot.roll = axes[1]
	plane.pilot.rudder = axes[2]
	plane.pilot.throttle = clampf(plane.pilot.throttle + float(axes[3]) * plane.pilot.throttle_rate * delta, 0, 1)
	plane.pilot.brakes = packet.get("brake") == true
	if packet.get("gear") is bool and plane.gear.retractable and not _lost(side): plane.gear.extended = packet.gear
	if packet.get("flaps") is bool and packet.flaps != plane.devices.flap_target:
		plane.devices.command_flaps(packet.flaps)
	for gun in DuelAircraft.batteries(plane):
		gun.external_fire = phase == "combat" and resolution < 0 and packet.get("fire") == true and not _lost(side)


func _start_combat() -> void:
	phase = "combat"
	deadline = elapsed + config.combat_seconds
	for plane in planes:
		plane.health.reset()
		plane.components.reset()
		plane.damage_effects.clear()
		for gun in DuelAircraft.batteries(plane):
			gun.reset()
			gun.trigger_ready = true


func _lost(side: int) -> bool:
	return planes[side].is_crashed or planes[side].is_destroyed


func _boundary(side: int) -> void:
	var offset := planes[side].global_position - DuelAircraft.CENTRE
	if Vector2(offset.x, offset.z).length() <= DuelAircraft.BOUNDARY:
		outside[side] = -1.0
	elif outside[side] < 0:
		outside[side] = elapsed + config.boundary_seconds
	elif elapsed >= outside[side]:
		_lose(side, "Combat boundary forfeit.", true)


func _lose(side: int, message: String, forfeit: bool) -> void:
	if losses[side]: return
	losses[side] = true
	forfeits[side] = forfeit
	if not forfeit:
		var plane := planes[side]
		var frames := Engine.get_physics_frames() - int(plane.get_meta("last_hostile_hit_frame", -1000000))
		kills[1 - side] = plane.get_meta("last_hostile_shooter_id", 0) == planes[1 - side].get_instance_id() and frames <= Engine.physics_ticks_per_second * float(config.credit_seconds)
	if resolution < 0:
		reason = message
		resolution = elapsed + config.mutual_seconds


func _finish(winner: int, message: String) -> void:
	if phase != "combat": return
	phase = "results"
	for plane in planes:
		for gun in DuelAircraft.batteries(plane):
			gun.reset(false)
		plane.freeze = true
		plane.components.set_process(false)
	completed.emit(winner, message, forfeits.duplicate(), kills.duplicate())


func _record_hit(target: FlightAircraft, point: Vector3, attacker: int) -> void:
	var slot := planes.find(target)
	if phase != "combat" or slot < 0 or slot == attacker: return
	hit_serial += 1
	recent_hits.append({"id":"%s:hit:%d" % [round_id, hit_serial],
		"target":_aircraft_id(slot), "attacker":_aircraft_id(attacker), "point":DuelAircraft.pack(point)})
	if recent_hits.size() > 16: recent_hits.pop_front()


func _aircraft_id(side: int) -> String:
	return "%s:%d:%d" % [round_id, side, flight_lives[side]]


func snapshot() -> Dictionary:
	serial += 1
	var states := []
	for side in 2:
		var plane := planes[side]
		var q := plane.global_basis.get_rotation_quaternion()
		var guns := DuelAircraft.batteries(plane)
		var ammo := 0
		var salvos := 0
		var tracers := []
		for gun in guns:
			salvos += gun.salvo_count
			for rounds in gun.remaining_by_port: ammo += rounds
			for index in gun.pool.active:
				if gun.pool.tracers[index].visible and tracers.size() < 24:
					tracers.append([DuelAircraft.pack(gun.pool.positions[index]), DuelAircraft.pack(gun.pool.velocities[index])])
		states.append({"id":_aircraft_id(side), "p": DuelAircraft.pack(plane.global_position), "q": [q.x, q.y, q.z, q.w],
			"v": DuelAircraft.pack(plane.pending_reset_velocity if phase == "loading" else plane.linear_velocity), "w": DuelAircraft.pack(plane.angular_velocity),
			"hp": plane.health.hp, "dead": plane.is_destroyed, "crashed": plane.is_crashed,
			"gear": plane.gear.extended, "flaps": plane.devices.flaps, "throttle": plane.pilot.throttle,
			"speed": plane.airspeed, "ammo": ammo, "salvos": salvos, "tracers": tracers,
			"fire": not plane.components.fires.is_empty(), "axes": [plane.pilot.pitch, plane.pilot.roll, plane.pilot.rudder],
			"integrity": plane.components.integrity, "detached": plane.components.detached.keys(),
			"breakup": plane.impact_effects.started, "water": plane.impact_effects.water,
			"slats": [plane.slats.x, plane.slats.y] if plane is Bf109 else [0, 0]})
	return {"type": "flight", "seq": serial, "phase": phase, "aircraft": states,
		"hits": recent_hits, "arrived": arrived, "remaining": maxf(0, deadline - elapsed),
		"outside": outside.map(func(t): return -1 if t < 0 else maxf(0, t - elapsed)),
		"disconnected": disconnected.map(func(t): return -1 if t < 0 else maxf(0, t - elapsed))}
