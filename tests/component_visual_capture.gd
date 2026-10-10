extends SceneTree
## Render the optional hitbox inspector and CPU fuel effects. Requires a display.
var world: Node3D
var aircraft: FlightAircraft
var output: String
var camera: Camera3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	output = args[0] if args.size() > 0 else "user://component_captures"
	var kind: String = args[1] if args.size() > 1 else "spitfire"
	DirAccess.make_dir_recursive_absolute(output)
	world = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.start_flight(kind)
	aircraft = world.aircraft
	aircraft.pilot.automated = true
	world.enemy.ai.combat_enabled = false
	aircraft.request_reset()
	aircraft.pending_reset_pose = Transform3D(Basis.IDENTITY, Vector3(0, 150, 400))
	aircraft.pending_reset_velocity = Vector3(0, 0, -55)
	await _frames(6)
	aircraft.pilot.throttle = 0.7
	world.component_debug.set_enabled(true)
	camera = Camera3D.new()
	camera.fov = 50
	aircraft.add_child(camera)
	camera.position = Vector3(12, 7, -13)
	camera.look_at(aircraft.global_position)
	camera.make_current()
	paused = true
	await _capture("healthy_hitboxes")
	aircraft.components.apply_damage(&"left_wing", 30)
	aircraft.components.apply_damage(&"engine", 10)
	await _capture("wing_engine_damage")
	world.component_debug.repair_selected()
	world.component_debug.part_picker.select(7)
	world.component_debug.force_fuel.button_pressed = true
	world.component_debug.apply_selected_damage()
	paused = false
	await _frames(120)
	await _capture("fuel_fire_above_50_hp")
	print(kind, " fuel visual HP=", aircraft.health.hp, " remaining=", aircraft.components.fuel_remaining, " particles=", aircraft.damage_effects.active_count())
	world.component_debug.repair_selected()
	camera.reparent(world.enemy)
	camera.position = Vector3(14, 7, -15)
	camera.look_at(world.enemy.global_position)
	world.component_debug.target_picker.select(1)
	world.component_debug._on_selection_changed(1)
	world.enemy.components.apply_damage(&"left_wing", 20)
	world.enemy.components.apply_damage(&"rudder", 10)
	world.enemy.components.apply_damage(&"engine", 10)
	paused = true
	await _capture("stuka_components")
	camera.reparent(world) # Session reset will free the old enemy.
	world.chase.make_current()
	paused = false
	aircraft.request_reset()
	await _frames(18)
	await _capture("reset_components")
	print("Component captures saved to ", output)
	quit()

func _frames(count: int) -> void:
	for tick in range(count):
		await physics_frame

func _capture(name: String) -> void:
	world.component_debug._refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	if picture.is_empty() or picture.save_png(output.path_join(name + ".png")) != OK:
		push_error("Unable to capture " + name)
		quit(1)
