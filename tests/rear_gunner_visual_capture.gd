extends SceneTree
## Graphical close-up of the rear gunner; never use this script for gameplay.
var world: Node3D
var player: FlightAircraft
var enemy: EnemyAircraft
var camera: Camera3D
var output: String

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	output = args[0] if not args.is_empty() else "user://rear_gunner_captures"
	DirAccess.make_dir_recursive_absolute(output)
	world = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.start_flight("spitfire")
	player = world.aircraft
	player.pilot.automated = true
	player.request_reset()
	player.pending_reset_pose = Transform3D(Basis.IDENTITY, Vector3(40, 235, 270))
	player.pending_reset_velocity = Vector3(0, 0, -55)
	await _frames(6)
	enemy = world.enemy
	enemy.ai.combat_enabled = false
	enemy.request_reset()
	enemy.pending_reset_pose = Transform3D(Basis.IDENTITY, Vector3(0, 200, 0))
	enemy.pending_reset_velocity = Vector3(0, 0, -55)
	await _frames(6)
	enemy.ai.set_physics_process(false)
	enemy.ai.combat_enabled = true
	enemy.ai.grace_period = 0
	enemy.ai.combat_unlocked = true
	enemy.ai.mode = "EVADE"
	enemy.ai.tactic = "BREAK RIGHT"
	player.freeze = true
	enemy.freeze = true
	camera = Camera3D.new()
	camera.fov = 48
	enemy.add_child(camera)
	camera.position = Vector3(6.5, 3.8, 8)
	camera.look_at(enemy.to_global(Vector3(0, 0.8, 1.2)))
	camera.make_current()
	await _frames(90)
	await _capture("rear_cockpit")
	enemy.rear_gunner.burst_clock = 0
	await _frames(2)
	await _capture("rear_mg15_firing")
	camera.position = Vector3(13, 5, 16)
	camera.look_at(enemy.global_position)
	await _capture("rear_stuka")
	world.component_debug.set_enabled(true)
	world.component_debug.target_picker.select(1)
	world.component_debug.part_picker.select(4)
	world.component_debug._on_selection_changed(1)
	await _capture("rear_cockpit_hitbox")
	print("Rear captures saved to ", output, " · gunner=", enemy.rear_gunner.status, " rounds=", enemy.rear_gunner.guns.pool.total_spawned)
	quit()

func _frames(count: int) -> void:
	for tick in range(count):
		await physics_frame

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	if frame.is_empty() or frame.save_png(output.path_join(name + ".png")) != OK:
		push_error("Unable to capture " + name)
		quit(1)
