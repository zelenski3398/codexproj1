extends SceneTree
## Real startup input, aircraft-dependent controls, live biplane physics/combat,
## and a measured full-throttle comparison using the same altitude controller.
var world: Node3D
var player: FlightAircraft
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await _frames(3)
	_check(world.aircraft == null and world.enemy == null and world.selector.buttons.size() == 2, "Startup presents both aircraft before spawning gameplay")
	_key(KEY_W, true)
	_key(KEY_CTRL, true)
	_key(KEY_H, true)
	_key(KEY_R, true)
	await _frames(120)
	for code in [KEY_W, KEY_CTRL, KEY_H, KEY_R]:
		_key(code, false)
	_check(world.aircraft == null and world.enemy == null and not paused, "Menu keys cannot accelerate, fire, damage, reset or pause a live aircraft")
	_key(KEY_RIGHT, true, true)
	_key(KEY_RIGHT, false, true)
	await _frames(2)
	_check(world.selector.selected == "sea_gladiator" and world.selector.preview is SeaGladiatorModel, "Keycode-only Right selects the Sea Gladiator and its biplane preview")
	_key(KEY_LEFT, true)
	_key(KEY_LEFT, false)
	await _frames(2)
	_check(world.selector.selected == "spitfire" and not world.selector.preview is SeaGladiatorModel, "Physical Left switches back to the Spitfire preview")
	_key(KEY_2, true, true)
	_key(KEY_2, false, true)
	_key(KEY_ENTER, true, true)
	_key(KEY_ENTER, false, true)
	await _frames(6)
	player = world.aircraft
	_check(player is SeaGladiator and player.model is SeaGladiatorModel and world.selector == null, "Enter starts the chosen Sea Gladiator through the real input pipeline")
	_check(player.health.hp == 100 and player.pilot.throttle == 0 and world.enemy.target == player and root.gui_get_focus_owner() == null, "Selection starts a clean life, points the enemy at it and releases GUI focus")
	var model: SeaGladiatorModel = player.model as SeaGladiatorModel
	_check(model.upper_wing != null and model.lower_wing != null and model.gun_ports.size() == 4 and model.wheel_roots.size() == 3, "Gladiator has stacked wings, four firing origins and three suspension-linked wheels")
	_key(KEY_W, true, true)
	_key(KEY_CTRL, true, true)
	_key(KEY_LEFT, true, true)
	_key(KEY_A, true, true)
	await _frames(60)
	_check(player.pilot.throttle > 0.1 and player.pilot.roll == 1 and player.pilot.rudder == 1 and player.guns.pool.total_spawned >= 24, "Gladiator accepts throttle/steering while Ctrl fires all four guns")
	for code in [KEY_W, KEY_CTRL, KEY_LEFT, KEY_A]:
		_key(code, false, true)
	_key(KEY_G, true)
	_key(KEY_G, false)
	await _frames(3)
	_check(player.gear.extended and not player.gear.retractable and player.gear.last_notice.contains("FIXED"), "G reports fixed gear and cannot retract it")
	_check(world.hud.gear_label.text == "FIXED" and world.hud.help_label.text.contains("115–135"), "HUD gives the selected aircraft's gear state and takeoff speed")
	_key(KEY_R, true)
	_key(KEY_R, false)
	await _frames(360)
	_check(player is SeaGladiator and player.health.hp == 100 and player.airspeed < 0.3 and player.gear.contact_count == 3, "Reset preserves the selected Gladiator and stable three-wheel parking")
	world.enemy.ai.combat_enabled = false
	player.pilot.automated = true
	player.pilot.throttle = 1
	var liftoff_speed: float = 0
	for tick in range(4800):
		player.pilot.pitch = clampf((0.10 - player.rotation.x) * 3, -0.5, 0.5) if player.airspeed > 30 else 0.0
		await physics_frame
		if liftoff_speed == 0 and player.gear.contact_count == 0 and player.altitude > 2:
			liftoff_speed = player.airspeed
		if player.is_crashed:
			break
	print("Gladiator takeoff speed=", liftoff_speed * 3.6, " km/h; altitude=", player.altitude)
	_check(not player.is_crashed and player.altitude > 15 and liftoff_speed > 24 and liftoff_speed < 40, "Gladiator accelerates and takes off using its lower-speed force model")
	_check(not player.gear.toggle() and player.gear.extended, "Fixed wheels stay extended in flight")
	await _fixture(Vector3(0, 200, 350), Vector3(0, 0, -48), 0.04)
	player.pilot.throttle = 0.8
	var forward: Vector3 = -player.global_basis.z
	player.pilot.roll = 0.35
	await _frames(180)
	player.pilot.roll = 0
	await _frames(480)
	_check(absf(player.global_basis.x.y) > 0.15 and forward.angle_to(-player.global_basis.z) > 0.15 and absf(player.linear_velocity.x) > 2, "Gladiator banks, changes heading and turns its actual velocity")
	await _fixture(Vector3(0, 160, 0), Vector3(0, 0, -18), 0)
	await _frames(30)
	_check(player.stalled, "Gladiator's lower-speed stall warning activates")
	player.pilot.throttle = 1
	for tick in range(1200):
		player.pilot.pitch = clampf((-0.17 - player.rotation.x) * 3, -0.7, 0.7)
		await physics_frame
		if player.airspeed > 34 and not player.stalled:
			break
	_check(not player.is_crashed and player.airspeed > 34 and not player.stalled, "Power and nose-down input recover the Gladiator's stall")
	await _fixture(Vector3(0, 3.8, 350), Vector3(0, -0.8, -34), 0.07)
	player.pilot.throttle = 0.04
	var touched: bool = false
	var bounce: float = 0
	for tick in range(2400):
		player.pilot.pitch = clampf((0.085 - player.rotation.x) * 3, -0.4, 0.4)
		if player.gear.contact_count > 0:
			touched = true
			player.pilot.throttle = 0
			player.pilot.brakes = true
		if touched:
			bounce = maxf(bounce, player.altitude)
		await physics_frame
		if player.is_crashed:
			break
	print("Gladiator landing: touched=", touched, " bounce=", bounce, " speed=", player.airspeed, " crash=", player.crash_reason)
	_check(touched and not player.is_crashed and bounce < 2.5, "Gladiator lands gently on fixed wheels without excessive bounce")
	_check(player.airspeed < 1, "Space-equivalent wheel brakes stop the Gladiator")
	player.pilot.brakes = false
	player.pilot.throttle = 1
	for tick in range(4200):
		player.pilot.pitch = clampf((0.10 - player.rotation.x) * 3, -0.5, 0.5) if player.airspeed > 30 else 0.0
		await physics_frame
	_check(not player.is_crashed and player.altitude > 15 and player.gear.contact_count == 0, "Landed Gladiator takes off again without reset")
	# The actual four guns must hit a moving enemy, not just spawn tracers.
	await _fixture(Vector3(0, 150, 500), Vector3(0, 0, -48), 0)
	world.enemy.request_reset()
	world.enemy.pending_reset_pose = Transform3D(Basis.IDENTITY, Vector3(0, 150, 250))
	world.enemy.pending_reset_velocity = Vector3(0, 0, -48)
	await _frames(5)
	player.pilot.fire = true
	await _frames(120)
	player.pilot.fire = false
	_check(world.enemy.health.hp < 100 and player.guns.pool.total_hits > 0 and player.health.hp == 100, "Gladiator's real four-gun projectiles damage an airborne enemy and exclude their owner")
	await _fixture(Vector3(0, 150, 200), Vector3(0, 0, -48), 0)
	world.enemy.request_reset()
	world.enemy.pending_reset_pose = Transform3D(Basis.IDENTITY, Vector3(0, 150, 500))
	world.enemy.pending_reset_velocity = Vector3(0, 0, -48)
	world.enemy.ai.grace_period = 0
	world.enemy.ai.combat_enabled = true
	for tick in range(720):
		player.pilot.pitch = clampf((0.02 - player.rotation.x) * 4, -0.5, 0.5)
		await physics_frame
	_check(player.health.hp < 100 and world.enemy.guns.pool.total_hits > 0, "Enemy AI can shoot and damage the selected Gladiator")
	world.enemy.ai.combat_enabled = false
	await _fixture(Vector3(0, 160, 300), Vector3(0, 0, -48), 0)
	player.take_damage(50)
	await _frames(30)
	_check(not player.damage_effects.emitting and player.damage_effects.active_count() == 0, "Gladiator's exact 50-HP threshold keeps engine effects off")
	player.take_damage(10)
	await _frames(120)
	_check(player.damage_effects.emitting and player.damage_effects.active_count() > 0, "Damaged Gladiator emits engine smoke/fire in world space")
	player.take_damage(100)
	await _frames(30)
	_check(player.is_destroyed and player.pilot.throttle == 0 and player.guns.pool.active.is_empty() and world.hud.overlay_title.text == "DESTROYED", "Gladiator destruction disables engine/guns and offers reset")
	_key(KEY_R, true)
	_key(KEY_R, false)
	await _frames(6)
	_check(player is SeaGladiator and player.health.hp == 100 and world.enemy.health.hp == 100 and player.damage_effects.active_count() == 0, "Reset restores the selected Gladiator, enemy and clean damage effects")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await process_frame
	world.hud.change_aircraft_button.pressed.emit()
	await _frames(5)
	_check(not paused and world.aircraft == null and world.enemy == null and world.selector.selected == "sea_gladiator", "Pause-menu aircraft change clears the old encounter and remembers the selection")
	_key(KEY_1, true)
	_key(KEY_1, false)
	_key(KEY_ENTER, true)
	_key(KEY_ENTER, false)
	await _frames(5)
	_check(world.aircraft.model is SpitfireModel and not world.aircraft is SeaGladiator and world.aircraft.model.gun_ports.size() == 8 and world.aircraft.gear.retractable, "Choosing Spitfire restores the original model, eight guns and retractable gear")
	var spitfire: Dictionary = await _performance("spitfire")
	var gladiator: Dictionary = await _performance("sea_gladiator")
	print("Full-power performance: Spitfire=", spitfire, " Sea Gladiator=", gladiator)
	_check(gladiator.speed < spitfire.speed * 0.82 and gladiator.speed > 45, "Measured full-throttle level speed is substantially lower than the Spitfire's")
	_check(gladiator.acceleration_speed < spitfire.acceleration_speed - 1, "Measured five-second acceleration is slower than the Spitfire's")
	_check(gladiator.climb < spitfire.climb, "Measured full-power climb is weaker than the Spitfire's")
	var aircraft_count: int = 0
	for child in world.get_children():
		if child is FlightAircraft:
			aircraft_count += 1
	_check(aircraft_count == 2 and world.get_node("CountrysideAirfield") != null, "Repeated aircraft changes leave exactly one player, one enemy and one airfield")
	print("AIRCRAFT CHOICE RESULT: ", checks - failures, "/", checks, " passed; ", failures, " failed")
	quit(1 if failures else 0)

func _performance(kind: String) -> Dictionary:
	world.show_selection()
	world.start_flight(kind)
	player = world.aircraft
	world.enemy.ai.combat_enabled = false
	await _fixture(Vector3(0, 800, 2200), Vector3(0, 0, -40), 0)
	if player.gear.retractable:
		player.gear.extended = false
	player.pilot.throttle = 1
	var early: float = 0
	for tick in range(5400):
		var pitch: float = asin(clampf((-player.global_basis.z).y, -1, 1))
		var desired: float = clampf(0.02 + (800 - player.global_position.y) * 0.006, -0.15, 0.18)
		player.pilot.pitch = clampf((desired - pitch) * 4, -0.6, 0.6)
		await physics_frame
		if tick == 599:
			early = player.airspeed
	var speed: float = player.airspeed
	var y: float = player.global_position.y
	for tick in range(2400):
		player.pilot.pitch = clampf((0.10 - player.rotation.x) * 4, -0.6, 0.6)
		await physics_frame
	return {"speed": speed, "acceleration_speed": early, "climb": (player.global_position.y - y) / 20.0}

func _fixture(position: Vector3, velocity: Vector3, pitch: float) -> void:
	player.pilot.automated = true
	player.request_reset()
	player.pending_reset_pose = Transform3D(Basis(Vector3.RIGHT, pitch), position)
	player.pending_reset_velocity = velocity
	await _frames(6)
	player.pilot.throttle = 0.5

func _frames(count: int) -> void:
	for tick in range(count):
		await physics_frame

func _key(code: Key, pressed: bool, logical_only: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = 0 if logical_only else code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
