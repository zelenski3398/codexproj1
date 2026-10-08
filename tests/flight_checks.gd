extends SceneTree
## Deterministic integration checks exercise the live RigidBody3D and terrain.
## Fixture teleports are confined to scenario setup, never gameplay flight.
var aircraft: FlightAircraft
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://main.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	aircraft = world.aircraft
	world.enemy.ai.combat_enabled = false
	aircraft.pilot.automated = true
	await _frames(360)
	_check(not aircraft.is_crashed, "Stationary aircraft survives suspension settling")
	_check(aircraft.gear.contact_count == 3, "All three wheels support the parked aircraft")
	_check(aircraft.linear_velocity.length() < 0.3, "Parked suspension settles without drift or bouncing")
	_check(not aircraft.gear.toggle() and aircraft.gear.extended, "Weight-on-wheels prevents gear retraction")
	print("Parked: ", aircraft.global_position, " velocity=", aircraft.linear_velocity)
	# Fixed throttle and real elevator torque for a runway takeoff.
	aircraft.pilot.throttle = 1.0
	var max_altitude := 0.0
	for tick in range(4800):
		if aircraft.airspeed > 44.0:
			aircraft.pilot.pitch = clampf((0.12 - aircraft.rotation.x) * 3.0, -0.5, 0.5)
		await physics_frame
		max_altitude = maxf(max_altitude, aircraft.altitude)
		if tick % 600 == 0:
			print("Takeoff t=", tick / 120.0, " speed=", aircraft.airspeed, " alt=", aircraft.altitude, " pitch=", aircraft.rotation.x, " wheels=", aircraft.gear.contact_count)
		if aircraft.is_crashed:
			break
	_check(not aircraft.is_crashed and max_altitude > 15.0 and aircraft.gear.contact_count == 0, "Full power and elevator produce a real takeoff and climb")
	_check(aircraft.pilot.throttle == 1.0, "Throttle holds its setting without continued input")
	_check(aircraft.gear.toggle() and not aircraft.gear.extended, "Gear retracts while airborne")
	var original_forward := -aircraft.global_basis.z
	aircraft.pilot.roll = 0.45
	await _frames(180)
	aircraft.pilot.roll = 0.0
	await _frames(480)
	print("Turn: bank=", aircraft.global_basis.x.y, " heading_change=", original_forward.angle_to(-aircraft.global_basis.z), " velocity=", aircraft.linear_velocity)
	_check(absf(aircraft.global_basis.x.y) > 0.15, "Roll torque banks the aircraft")
	_check(original_forward.angle_to(-aircraft.global_basis.z) > 0.12, "Banking produces a coordinated heading change")
	_check(absf(aircraft.linear_velocity.x) > 2.0, "Aerodynamic forces turn the velocity, not just the model")
	await _fixture(Vector3(0, 160, 0), Vector3(0, 0, -65), 0.03, false)
	aircraft.pilot.throttle = 0.7
	aircraft.pilot.roll = -0.35
	await _frames(120)
	aircraft.pilot.roll = 0.0
	await _frames(480)
	_check(aircraft.global_basis.x.y < -0.2 and aircraft.linear_velocity.x > 3.0 and aircraft.global_basis.z.x < -0.1, "Right bank turns both heading and velocity to the right")
	await _fixture(Vector3(0, 160, 0), Vector3(0, 0, -60), 0.03, false)
	aircraft.pilot.rudder = 0.8
	await _frames(240)
	_check(aircraft.global_basis.z.x > 0.08, "Manual left rudder produces left yaw")
	await _fixture(Vector3(0, 150, 0), Vector3(0, 0, -22), 0.03, false)
	aircraft.pilot.throttle = 0.0
	await _frames(30)
	_check(aircraft.stalled, "Low airspeed triggers the stall warning")
	aircraft.pilot.throttle = 1.0
	for tick in range(1800):
		aircraft.pilot.pitch = clampf((-0.17 - aircraft.rotation.x) * 3.0, -0.7, 0.7)
		await physics_frame
		if aircraft.airspeed > 40.0 and not aircraft.stalled:
			break
	_check(not aircraft.is_crashed and aircraft.airspeed > 40.0 and not aircraft.stalled, "Lowering the nose and adding power recover from the stall")
	await _fixture(Vector3(0, 150, 0), Vector3(0, -18, -45), 0.35, false)
	await _frames(2)
	_check(aircraft.stalled and absf(aircraft.angle_of_attack) > deg_to_rad(16.0), "Excessive angle of attack also stalls")
	# Approach fixtures use physically integrated descent from above the runway.
	await _fixture(Vector3(0, 3.8, 350), Vector3(0, -0.9, -46), 0.07, true)
	aircraft.pilot.throttle = 0.08
	var touched := false
	var max_bounce := 0.0
	for tick in range(2400):
		aircraft.pilot.pitch = clampf((0.085 - aircraft.rotation.x) * 3.0, -0.4, 0.4)
		if aircraft.gear.contact_count > 0:
			touched = true
			aircraft.pilot.throttle = 0.0
			aircraft.pilot.brakes = true
		if touched:
			max_bounce = maxf(max_bounce, aircraft.altitude)
		await physics_frame
		if aircraft.is_crashed:
			break
	print("Landing: touched=", touched, " speed=", aircraft.airspeed, " altitude=", aircraft.altitude, " peak_after_contact=", max_bounce, " crash=", aircraft.crash_reason)
	_check(touched and not aircraft.is_crashed, "Gear-down gentle landing survives touchdown")
	_check(touched and aircraft.airspeed < 1.0, "Wheel brakes stop the landed aircraft")
	_check(max_bounce < 2.5, "Landing suspension avoids excessive bouncing")
	aircraft.pilot.brakes = false
	aircraft.pilot.throttle = 1.0
	for tick in range(4200):
		aircraft.pilot.pitch = clampf((0.12 - aircraft.rotation.x) * 3.0, -0.5, 0.5) if aircraft.airspeed > 44.0 else 0.0
		await physics_frame
	_check(not aircraft.is_crashed and aircraft.altitude > 15.0 and aircraft.gear.contact_count == 0, "Landed aircraft takes off again without reset")
	aircraft.request_reset()
	await _frames(240)
	_check(not aircraft.is_crashed and aircraft.gear.extended and aircraft.airspeed < 0.3 and aircraft.global_position.distance_to(aircraft.reset_position) < 0.5, "Reset restores a safe stationary runway start")
	world.chase.global_position = aircraft.global_position + Vector3(0, -5, 19)
	world.chase.initialized = true
	await _frames(3)
	_check(world.chase.global_position.y >= 1.5, "Chase camera corrects a below-terrain position")
	# Test the literal keyboard mapping, held throttle rate and pause gate too.
	aircraft.pilot.automated = false
	Input.action_press("throttle_up")
	await _frames(120)
	Input.action_release("throttle_up")
	var held := aircraft.pilot.throttle
	await _frames(60)
	_check(held > 0.25 and held < 0.35 and is_equal_approx(aircraft.pilot.throttle, held), "W ramps throttle and releasing W holds it")
	Input.action_press("throttle_down")
	await _frames(60)
	Input.action_release("throttle_down")
	_check(aircraft.pilot.throttle < held - 0.1, "S decreases throttle")
	Input.action_press("pitch_down")
	Input.action_press("roll_left")
	Input.action_press("rudder_right")
	await _frames(2)
	_check(aircraft.pilot.pitch < 0 and aircraft.pilot.roll > 0 and aircraft.pilot.rudder < 0, "Arrow and rudder signs match the specified controls")
	Input.action_release("pitch_down")
	Input.action_release("roll_left")
	Input.action_release("rudder_right")
	aircraft.pilot.automated = true
	paused = true
	var paused_position := aircraft.global_position
	await _frames(60)
	_check(aircraft.global_position.is_equal_approx(paused_position), "Pause stops aircraft physics")
	paused = false
	await _fixture(Vector3(0, 8, 200), Vector3(0, -10, -40), 0.0, true)
	await _frames(200)
	_check(aircraft.is_crashed, "Severe landing impact enters the crash state")
	aircraft.request_reset()
	await _frames(180)
	_check(not aircraft.is_crashed, "Reset recovers a crashed aircraft")
	await _fixture(Vector3(0, 2, 200), Vector3(0, -3, -38), 0.0, false)
	await _frames(240)
	_check(aircraft.is_crashed, "Belly landing without gear enters the crash state")
	print("RESULT: ", checks - failures, "/", checks, " passed; ", failures, " failed")
	quit(1 if failures > 0 else 0)

func _fixture(pos: Vector3, velocity: Vector3, pitch: float, gear_down: bool) -> void:
	aircraft.request_reset()
	aircraft.pending_reset_pose = Transform3D(Basis(Vector3.RIGHT, pitch), pos)
	aircraft.pending_reset_velocity = velocity
	await _frames(3)
	aircraft.gear.extended = gear_down
	aircraft.airborne_time = 0.5
	await _frames(2)
	print("Fixture: position=", aircraft.global_position, " speed=", aircraft.airspeed)
	_check(absf(aircraft.global_position.y - pos.y) < 1.0 and aircraft.linear_velocity.distance_to(velocity) < 2.0, "Scenario reset applies the requested altitude and velocity")

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
