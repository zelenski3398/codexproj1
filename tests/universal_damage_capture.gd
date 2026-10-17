extends SceneTree
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	print("CAPTURE ",label,": ",root.get_texture().get_image().save_png("res://docs/previews/damage-"+label+".png"))
func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_flight("spitfire")
	var plane: FlightAircraft = world.aircraft
	plane.request_reset()
	plane.pending_reset_pose = Transform3D(Basis.IDENTITY,Vector3(0,8,500))
	await frames(5)
	plane.freeze = true
	world.enemy.freeze = true
	world.enemy.ai.set_physics_process(false)
	world.chase.set_process(false)
	world.chase.set_physics_process(false)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.global_position = plane.global_position+Vector3(-12,5,-14)
	camera.look_at(plane.global_position)
	camera.current = true
	camera.fov = 45
	plane.components.apply_damage(&"engine",45)
	plane.components.apply_damage(&"left_wing",15,plane.to_global(Vector3(-3.2,.05,-.3)))
	plane.components.ignite(&"engine")
	await create_timer(1.3).timeout
	await capture("engine-fire")
	plane.components.detach(&"left_wing")
	await create_timer(.3).timeout
	await capture("wing-separated")
	var bomber := ItalianEnemy.new()
	bomber.definition = EnemyAircraftDefinition.find("sm79")
	bomber.reset_position = Vector3(0,12,530)
	world.add_child(bomber)
	await frames(5)
	bomber.freeze = true
	bomber.ai.set_physics_process(false)
	bomber.components.apply_damage(&"engine_left",1000,Vector3.ZERO,false,"mechanical")
	camera.global_position = bomber.global_position+Vector3(-26,8,-25)
	camera.look_at(bomber.global_position)
	await create_timer(1.2).timeout
	await capture("bomber-engine")
	camera.global_position = plane.global_position+Vector3(-15,7,-17)
	camera.look_at(plane.global_position)
	bomber.hide()
	world.hud.hide()
	GameAudioMixer.instance.audio_button.hide()
	plane.components.catastrophic_failure("Explicit burning breakup capture")
	await create_timer(0.4).timeout
	await capture("catastrophic")
	print("BURNING_BREAKUP=",plane.impact_effects.explosion_count," FRAGMENTS=",plane.impact_effects.fragments.size())
	AircraftImpactService.obtain().clear_all()
	GameAudioMixer.instance.music.stop()
	GameAudioMixer.instance.music.stream = null
	world.queue_free()
	await frames(20)
	RenderingServer.force_sync()
	quit()
