extends SceneTree
## Optional rendered smoke check. Requires a real or virtual graphical display.
## godot --path . --script res://tests/visual_capture.gd -- /path/to/output
var aircraft: FlightAircraft
var world: Node3D
var output: String

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	output = args[0] if args.size() > 0 else "user://captures"
	DirAccess.make_dir_recursive_absolute(output)
	world = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	aircraft = world.aircraft
	world.enemy.ai.combat_enabled = false
	aircraft.pilot.automated = true
	for i in range(120):
		await physics_frame
	await _capture("runway")
	aircraft.request_reset()
	aircraft.pending_reset_pose = Transform3D(Basis.from_euler(Vector3(0.08, 0.0, 0.25)), Vector3(0, 160, 300))
	aircraft.pending_reset_velocity = Vector3(0, 0, -65)
	for i in range(3):
		await physics_frame
	aircraft.gear.extended = false
	aircraft.pilot.throttle = 0.7
	world.chase.snap()
	for i in range(90):
		await physics_frame
	await _capture("airborne")
	# Controlled encounter view, then a paused model inspection camera.
	world.enemy.request_reset()
	world.enemy.pending_reset_pose = Transform3D(Basis(Vector3.FORWARD, -0.15), aircraft.global_position + Vector3(14, 3, -48))
	world.enemy.pending_reset_velocity = Vector3(0, 0, -58)
	for i in range(5):
		await physics_frame
	await _capture("enemy_encounter")
	paused = true
	world.hud.visible = false
	var inspection: Camera3D = Camera3D.new()
	inspection.fov = 45.0
	world.add_child(inspection)
	inspection.global_position = world.enemy.global_position + Vector3(13, 6, -14)
	inspection.look_at(world.enemy.global_position)
	inspection.make_current()
	await _capture("stuka_reference_model")
	inspection.queue_free()
	world.chase.make_current()
	world.hud.visible = true
	paused = false
	print("Rendered flight altitude: ", aircraft.altitude)
	aircraft.take_damage(50)
	await _capture("hp50_no_effects")
	aircraft.take_damage(30)
	aircraft.pilot.fire = true
	for i in range(120):
		await physics_frame
	# Trigger a fresh salvo so the capture includes the very short flashes.
	aircraft.guns._fire_salvo()
	await _capture("firing_and_engine_damage")
	aircraft.pilot.fire = false
	paused = true
	await process_frame
	await _capture("paused")
	paused = false
	aircraft.take_damage(100)
	for i in range(30):
		await physics_frame
	await _capture("destroyed")
	aircraft.request_reset()
	for i in range(3):
		await physics_frame
	await _capture("reset")
	print("Rendered captures saved to ", output)
	quit()

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	if picture.is_empty() or picture.save_png(output.path_join(name + ".png")) != OK:
		push_error("Unable to capture " + name)
		quit(1)
