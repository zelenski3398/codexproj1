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
	print("Rendered flight altitude: ", aircraft.altitude)
	paused = true
	await process_frame
	await _capture("paused")
	print("Rendered captures saved to ", output)
	quit()

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	if picture.is_empty() or picture.save_png(output.path_join(name + ".png")) != OK:
		push_error("Unable to capture " + name)
		quit(1)
