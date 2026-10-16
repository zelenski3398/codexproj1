extends SceneTree
## Graphical showcase fixtures only; no gameplay state changes are exposed.
var world: Node3D
var camera: Camera3D
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/italian-captures")
	world = preload("res://main.tscn").instantiate()
	root.add_child(world)
	await _capture("main-menu")
	world.show_missions()
	await _capture("mission-briefing")
	world.start_interception("spitfire")
	for tick in range(180):
		await physics_frame
	await _capture("mission-ground-start")
	world.malta_mission.canvas.visible = false
	world.interception.canvas.visible = false
	camera = Camera3D.new()
	camera.fov = 45
	camera.far = 100000
	world.add_child(camera)
	camera.make_current()
	for kind in ["cr42", "c200", "c202", "sm79"]:
		var enemy: EnemyAircraft = world.create_encounter_enemy(Vector3(0, 1000, 0), false, kind)
		for tick in range(3):
			await physics_frame
		enemy.freeze = true
		enemy.ai.set_physics_process(false)
		var distance: float = 32 if kind == "sm79" else 16
		camera.global_position = enemy.global_position + Vector3(distance, distance * 0.48, -distance)
		camera.look_at(enemy.global_position)
		await _capture(kind)
		enemy.queue_free()
	quit()
func _capture(filename: String) -> void:
	for tick in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/italian-captures/" + filename + ".png")
