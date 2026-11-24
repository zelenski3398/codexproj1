class_name DuelView
extends Node3D

signal loaded
signal command(packet: Dictionary)

var world: MaltaWorld
var planes: Array[FlightAircraft] = []
var side: int
var kinds: Array
var state: Dictionary = {}
var sequence := 0
var snapshot_no := 0
var snapshot_clock := 0.0
var control_clock := 0.0
var gear_down := true
var flaps := false
var camera: ChaseCamera
var hud: Label
var waypoint: Label
var tracers: MeshInstance3D
var lines := ImmediateMesh.new()
var last_salvos := [0, 0]
var visuals := []
var desired: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
var received := [false, false]
var snapshot_velocity: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var snapshot_spin: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var active := false
var fight_flash := 0.0


func _ready() -> void:
	world = MaltaWorld.new()
	world.duel_only = true
	add_child(world)
	for slot in 2:
		var plane := DuelAircraft.make(self, kinds[slot], slot)
		planes.append(plane)
		DuelAircraft.spawn(plane, world, slot)
		plane.reset_completed.connect(func():
			plane.freeze = true
			plane.engine_running = true
			plane.gear.extended = slot == 0 or not plane.gear.retractable
		, CONNECT_ONE_SHOT)
		for gun in DuelAircraft.batteries(plane): gun.pool.set_physics_process(false)
	gear_down = side == 0 or not planes[side].gear.retractable
	camera = ChaseCamera.new()
	camera.aircraft = planes[side]
	add_child(camera)
	camera.far = 40000
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Label.new()
	hud.position = Vector2(24, 24)
	hud.add_theme_font_size_override("font_size", 21)
	hud.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(hud)
	waypoint = Label.new()
	waypoint.text = "◇ Rendezvous"
	waypoint.add_theme_font_size_override("font_size", 18)
	waypoint.add_theme_color_override("font_color", Color("efd28c"))
	canvas.add_child(waypoint)
	tracers = MeshInstance3D.new()
	tracers.mesh = lines
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ffe0a0")
	tracers.material_override = material
	tracers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tracers)
	_boundary()
	_wait_until_loaded.call_deferred()


func _wait_until_loaded() -> void:
	while is_inside_tree() and planes.any(func(plane): return plane.reset_pending):
		await get_tree().physics_frame
	if is_inside_tree(): loaded.emit()


func _boundary() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("e6b862")
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for i in 96:
		var p := DuelAircraft.CENTRE + Vector3(cos(i * TAU / 96), 0, sin(i * TAU / 96)) * DuelAircraft.BOUNDARY
		var q := DuelAircraft.CENTRE + Vector3(cos((i+1) * TAU / 96), 0, sin((i+1) * TAU / 96)) * DuelAircraft.BOUNDARY
		for height in [300, 650, 1000]:
			mesh.surface_add_vertex(p + Vector3.UP * height)
			mesh.surface_add_vertex(q + Vector3.UP * height)
		if i % 4 == 0:
			mesh.surface_add_vertex(p + Vector3.UP * 300)
			mesh.surface_add_vertex(p + Vector3.UP * 1000)
	mesh.surface_end()
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	add_child(ring)


func apply_snapshot(packet: Dictionary) -> void:
	if int(packet.seq) <= snapshot_no: return
	snapshot_no = int(packet.seq)
	snapshot_clock = 0.0
	if packet.phase == "combat" and state.get("phase") != "combat": fight_flash = 2.0
	state = packet
	active = packet.phase in ["preparation", "combat"]
	visuals.clear()
	for slot in 2:
		var data: Dictionary = packet.aircraft[slot]
		var plane := planes[slot]
		var q: Array = data.q
		desired[slot] = Transform3D(Basis(Quaternion(q[0], q[1], q[2], q[3]).normalized()), DuelAircraft.vector(data.p))
		snapshot_velocity[slot] = DuelAircraft.vector(data.v)
		snapshot_spin[slot] = DuelAircraft.vector(data.w)
		if plane.reset_pending: continue
		var dead: bool = data.dead or data.crashed
		var was_dead := plane.is_destroyed or plane.is_crashed
		if not received[slot] or (was_dead and not dead) or plane.global_position.distance_to(desired[slot].origin) > 65:
			plane.global_transform = desired[slot]
			plane.linear_velocity = snapshot_velocity[slot]
			plane.angular_velocity = snapshot_spin[slot]
			if slot == side:
				gear_down = data.gear
				flaps = false
				camera.snap()
		if was_dead and not dead:
			plane.impact_effects.reset()
			plane.components.reset()
			plane.health.reset()
		if data.dead and not plane.is_destroyed: plane.health.set_hp(0)
		if data.crashed and not data.dead and not plane.is_crashed: plane._crash("Aircraft lost")
		if data.breakup and data.dead and not plane.impact_effects.started:
			plane.impact_effects.water_point = desired[slot].origin
			plane.impact_effects.start(data.water)
		for component in data.detached:
			plane.components.detach(StringName(component))
		for component in data.integrity:
			var id := StringName(component)
			if plane.components.integrity.has(id): plane.components.integrity[id] = float(data.integrity[component])
		if plane is Bf109: plane.slats = Vector2(data.slats[0], data.slats[1])
		if slot != side:
			plane.pilot.pitch = data.axes[0]
			plane.pilot.roll = data.axes[1]
			plane.pilot.rudder = data.axes[2]
		plane.is_destroyed = data.dead
		plane.is_crashed = data.crashed
		plane.freeze = slot != side or not active or dead
		plane.health.hp = data.hp
		plane.damage_effects.set_health(data.hp, plane.health.max_hp)
		plane.damage_effects.set_fuel_fire(data.fire, Vector3.ZERO)
		plane.pilot.throttle = data.throttle
		plane.gear.extended = data.gear
		plane.devices.flaps = data.flaps
		plane.devices.sync_visuals()
		plane.airspeed = data.speed
		if data.salvos > last_salvos[slot] and received[slot]:
			plane.guns.flash_times.fill(.05)
			plane.guns.salvo_fired.emit(int(data.salvos) - last_salvos[slot])
		last_salvos[slot] = int(data.salvos)
		received[slot] = true
		for tracer in data.tracers:
			visuals.append([DuelAircraft.vector(tracer[0]), DuelAircraft.vector(tracer[1])])


func _unhandled_input(event: InputEvent) -> void:
	if not active or event.is_echo() or event.is_released(): return
	if event.is_action_pressed("gear") and planes[side].gear.retractable:
		gear_down = not gear_down
	elif event.is_action_pressed("flaps"):
		flaps = not flaps
	elif event.is_action_pressed("reset"):
		command.emit({"type":"reset"})


func _physics_process(delta: float) -> void:
	if planes.size() != 2: return
	snapshot_clock += delta
	for slot in 2:
		if not received[slot]: continue
		var plane := planes[slot]
		var target := desired[slot]
		target.origin += snapshot_velocity[slot] * minf(snapshot_clock, .1)
		if slot != side or plane.freeze:
			plane.global_transform = plane.global_transform.interpolate_with(target, 1 - exp(-delta * 16))
		else:
			plane.global_transform = plane.global_transform.interpolate_with(target, 1 - exp(-delta * 4))
			plane.linear_velocity = plane.linear_velocity.lerp(snapshot_velocity[slot], 1 - exp(-delta * 5))
			plane.angular_velocity = plane.angular_velocity.lerp(snapshot_spin[slot], 1 - exp(-delta * 5))
	if not active or not received[side]: return
	var axes := [Input.get_axis("pitch_down", "pitch_up"), Input.get_axis("roll_right", "roll_left"),
		Input.get_axis("rudder_right", "rudder_left"), Input.get_axis("throttle_down", "throttle_up")]
	var plane := planes[side]
	plane.pilot.pitch = axes[0]
	plane.pilot.roll = axes[1]
	plane.pilot.rudder = axes[2]
	plane.pilot.throttle = clampf(plane.pilot.throttle + float(axes[3]) * plane.pilot.throttle_rate * delta, 0, 1)
	plane.pilot.brakes = Input.is_action_pressed("brake")
	control_clock += delta
	if control_clock >= .04:
		control_clock = 0
		sequence += 1
		command.emit({"type":"input", "seq":sequence, "axes":axes, "brake":plane.pilot.brakes,
			"fire":Input.is_action_pressed("fire"), "gear":gear_down, "flaps":flaps})


func _process(delta: float) -> void:
	if not is_instance_valid(hud): return
	lines.clear_surfaces()
	if not visuals.is_empty() and snapshot_clock < .3:
		lines.surface_begin(Mesh.PRIMITIVE_LINES)
		for tracer in visuals:
			var tip: Vector3 = tracer[0] + tracer[1] * minf(snapshot_clock, .12)
			lines.surface_add_vertex(tip)
			lines.surface_add_vertex(tip - (tracer[1] as Vector3).normalized() * 8)
		lines.surface_end()
	waypoint.visible = not state.is_empty() and state.phase == "preparation"
	if state.is_empty():
		hud.text = "Preparing Malta…"
		return
	var data: Dictionary = state.aircraft[side]
	var label := "PREPARATION · weapons safe" if state.phase == "preparation" else "COMBAT"
	var guide := ""
	if state.phase == "loading": label = "WAITING FOR BOTH PLAYERS"
	if state.phase == "preparation":
		var delta_position: Vector3 = DuelAircraft.WAYPOINTS[side] - planes[side].global_position
		var bearing := roundi(fposmod(rad_to_deg(atan2(delta_position.x, -delta_position.z)), 360))
		guide = "\nRendezvous · %d m · %03d° · altitude 480 m" % [roundi(delta_position.length()), bearing]
		if state.arrived[side]: guide = "\nRendezvous reached · stay nearby"
		if data.dead or data.crashed: guide = "\nAircraft lost · R to reset before the deadline"
		var point: Vector3 = DuelAircraft.WAYPOINTS[side]
		var screen := get_viewport().get_visible_rect().size
		var projected := camera.unproject_position(point) if not camera.is_position_behind(point) else screen * Vector2(.45,.9)
		waypoint.position = Vector2(clampf(projected.x, 12, screen.x - 160), clampf(projected.y, 95, screen.y - 40))
	if state.outside[side] >= 0: guide = "\nReturn inside the combat boundary · %ds" % ceili(state.outside[side])
	if state.disconnected[1-side] >= 0: guide += "\nOpponent reconnecting · %ds" % ceili(state.disconnected[1-side])
	if snapshot_clock > 1.2: guide += "\nWaiting for server updates…"
	fight_flash = maxf(0, fight_flash - delta)
	hud.text = "%s · %ds\nHull %d%% · %d km/h · %d rounds%s" % [
		"FIGHT!" if fight_flash > 0 else label, ceili(state.remaining),
		roundi(float(data.hp) / planes[side].health.max_hp * 100), roundi(float(data.speed) * 3.6), int(data.ammo), guide]

func _exit_tree() -> void:
	if not is_instance_valid(AircraftImpactService.instance): return
	for plane in planes:
		AircraftImpactService.instance.clear_owner(plane.get_instance_id())
