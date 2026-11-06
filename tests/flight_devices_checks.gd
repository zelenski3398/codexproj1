extends SceneTree
var plane: FlightAircraft
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	if "--hz60" in OS.get_cmdline_user_args(): Engine.physics_ticks_per_second = 60
	call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + text)
func frames(n: int) -> void:
	for i in maxi(1,roundi(n * Engine.physics_ticks_per_second / 120.0)): await physics_frame
func fixture(speed: float = 65, pitch: float = 0) -> void:
	plane.request_reset()
	plane.pending_reset_pose = Transform3D(Basis(Vector3.RIGHT,pitch),Vector3(0,1500,0))
	plane.pending_reset_velocity = -plane.pending_reset_pose.basis.z * speed
	await frames(6)
	plane.pilot.automated = true
	plane.gear.extended = false
	plane.pilot.throttle = 0
func coast(flaps: bool, brakes: bool, pitch: float = 0) -> float:
	await fixture(65, pitch)
	plane.devices.flaps = 1 if flaps else 0
	plane.devices.airbrakes = 1 if brakes else 0
	plane.devices.flap_target = flaps
	plane.devices.brake_target = brakes
	for i in 6 * Engine.physics_ticks_per_second:
		# Identical modest attitude hold through elevator commands, no altitude lock.
		plane.pilot.pitch = clampf((pitch-plane.rotation.x)*3,-.6,.6)
		await physics_frame
	return plane.linear_velocity.length()
func run() -> void:
	var world := Node3D.new();root.add_child(world)
	plane = FlightAircraft.new();plane.input_enabled = false;plane.gameplay_airbrake_assist = true
	world.add_child(plane)
	await frames(3)
	var clean := await coast(false,false)
	var flap := await coast(true,false)
	var brake := await coast(false,true)
	var both := await coast(true,true)
	print("COAST 6 seconds from 65 m/s: clean=",clean," flaps=",flap," brakes=",brake," both=",both)
	check(clean < 65, "Idle retracted aircraft genuinely decelerates")
	check(flap < clean-2, "Flaps produce additional deceleration through drag")
	check(brake < flap and both < brake, "Airbrakes and combined devices progressively increase drag")
	var dive_clean := await coast(false,false,-.8)
	var dive_brake := await coast(false,true,-.8)
	print("DIVE clean=",dive_clean," brakes=",dive_brake)
	check(dive_brake < dive_clean, "Dive brake opposes air-relative motion in descent")
	check(dive_clean > clean, "Gravity still accelerates a steep unbraked dive")
	await fixture(35)
	await frames(60)
	var clean_sink := plane.linear_velocity.y
	await fixture(35)
	plane.devices.flaps=1;plane.devices.flap_target=true
	await frames(60)
	check(plane.linear_velocity.y > clean_sink, "Landing flaps add physical lift at approach speed")
	plane.devices.command_flaps(false)
	await frames(180)
	check(plane.devices.flaps < 1 and plane.linear_velocity.y < 0, "Retraction smoothly removes lift without freezing altitude")
	await fixture(30)
	await frames(2)
	check(plane.stalled,"Clean wing warns below existing 32 m/s stall threshold")
	await fixture(30)
	plane.devices.flaps=1;plane.devices.flap_target=true
	await frames(2)
	check(not plane.stalled,"Deployed flaps lower stall threshold naturally with increased maximum lift")
	await fixture(15)
	plane.devices.flaps=1;plane.devices.flap_target=true
	await frames(30)
	check(plane.stalled and plane.linear_velocity.y < 0, "Flaps do not prevent low-speed stalls or falling")
	await fixture(85)
	check(not plane.devices.command_flaps(true) and plane.devices.notice=="FLAPS OVERSPEED" and not plane.devices.flap_target,"Overspeed request rejected with explicit warning")
	await fixture(50)
	var before := plane.linear_velocity
	check(plane.devices.command_flaps(true) and plane.devices.command_airbrakes(true) and plane.linear_velocity==before,"Commands never directly change velocity")
	await frames(60)
	check(plane.devices.flaps>0 and plane.devices.flaps<1 and plane.devices.airbrakes>0 and plane.devices.airbrakes<1,"Deployment is gradual in physics time")
	check(is_equal_approx(plane.devices.surfaces[0].rotation.x,deg_to_rad(plane.flap_landing_degrees*plane.devices.flaps)),"Visual flap angle matches physical deployment")
	plane.take_damage(100)
	var deployed := plane.devices.flaps
	check(not plane.devices.command_flaps(false) and not plane.devices.command_airbrakes(false),"Destroyed aircraft reject deployment commands")
	await frames(12)
	check(is_equal_approx(deployed,plane.devices.flaps),"Wreck retains synchronised surface positions")
	await fixture()
	check(plane.devices.flaps==0 and plane.devices.airbrakes==0 and not plane.devices.flap_target and plane.devices.notice=="","Reset clears targets, surfaces and warnings")
	var unbraked := await coast(false,false)
	await fixture()
	plane.pilot.brakes=true
	for i in 6 * Engine.physics_ticks_per_second:
		plane.pilot.pitch=clampf(-plane.rotation.x*3,-.6,.6)
		await physics_frame
	check(absf(plane.linear_velocity.length()-unbraked)<.1,"Wheel brakes have no effect without ground contact")
	await fixture(25, -1.3)
	plane.devices.airbrakes=1;plane.devices.brake_target=true
	await frames(120)
	check(plane.linear_velocity.length()>25,"A steep slow dive can accelerate despite deployed airbrakes")
	var gladiator := SeaGladiator.new();world.add_child(gladiator)
	var stuka := EnemyAircraft.new();world.add_child(stuka)
	await frames(3)
	check(not gladiator.flaps_available and not gladiator.airbrakes_available,"Gladiator has no invented flaps or airbrakes")
	stuka.ai.set_physics_process(false)
	stuka.devices.flap_target=true;stuka.devices.brake_target=true
	stuka.devices.advance(.01)
	check(not stuka.devices.flap_target and not stuka.devices.brake_target,"AI retracts devices before normal manoeuvres through shared commands")
	check(stuka.flaps_available and stuka.airbrakes_available,"Stuka has landing flaps and separate dive brakes")
	check(not plane.airbrakes_available and plane.gameplay_airbrake_assist,"Spitfire dive brakes require explicit gameplay assist")
	var f := InputEventKey.new();f.physical_keycode=KEY_F
	var b := InputEventKey.new();b.physical_keycode=KEY_B
	check(f.is_action("flaps") and not f.is_action("fire") and b.is_action("airbrakes"),"F/B device bindings do not fire aircraft guns")
	world.queue_free();await frames(3)
	print("FLIGHT DEVICES RESULT: %d/%d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
