extends SceneTree
## Rendered fixtures use actual model, force-driven impact and water lifecycle.
var game: Node3D
var plane: FlightAircraft
var camera: Camera3D
func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for i in range(n):
		await physics_frame
func capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/aircraft-previews/" + file + ".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/aircraft-previews")
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_flight("spitfire")
	plane = game.aircraft
	game.enemy.ai.combat_enabled = false
	game.hud.hide()
	plane.pilot.automated = true
	await frames(5)
	plane.freeze = true
	plane.global_transform = Transform3D(Basis(Vector3.FORWARD, 0.25), Vector3(0, 50, 500))
	plane.gear.extended = false
	camera = Camera3D.new()
	game.add_child(camera)
	camera.fov = 42
	camera.position = plane.position + Vector3(12, 7, -13)
	camera.look_at(plane.position)
	camera.make_current()
	await frames(4)
	await capture("spitfire-reference")
	plane.gear.contact_count = 0 # Frozen airborne presentation fixture has no wheel contacts.
	plane.take_damage(999)
	await frames(8)
	await capture("airborne-explosion")
	plane.freeze = false
	plane.request_reset()
	plane.pending_reset_pose = Transform3D(Basis.IDENTITY, Vector3(0, 5, 500))
	plane.pending_reset_velocity = Vector3(0, -30, -40)
	camera.position = Vector3(13, 6, 483)
	camera.look_at(Vector3(0, 1, 495))
	for i in range(120):
		await physics_frame
		if plane.impact_effects.started:
			break
	await frames(18)
	await capture("ground-breakup")
	# Independent sea fixture uses the same water group as MaltaWorld.
	var sea := StaticBody3D.new()
	sea.add_to_group("aircraft_water")
	game.add_child(sea)
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	sea.add_child(shape)
	plane.add_collision_exception_with(sea)
	plane.impact_effects.water_rids.append(sea.get_rid())
	plane.request_reset()
	plane.pending_reset_pose = Transform3D(Basis.IDENTITY, Vector3(20000, 3, 0))
	plane.pending_reset_velocity = Vector3(0, -12, -15)
	MeshKit.box(game, Vector3(500, 0.1, 500), Vector3(20000, -0.05, 0), MeshKit.material(Color("24566c")))
	camera.position = Vector3(20012, 5, -18)
	camera.look_at(Vector3(20000, 0, -4))
	for i in range(120):
		await physics_frame
		if plane.impact_effects.water:
			break
	await frames(12)
	await capture("water-plunge")
	AircraftImpactService.instance.clear_all()
	OS.delay_msec(100) # Allow the native mixer to retire stopped Ogg playbacks.
	game.queue_free()
	await frames(3)
	quit()
