extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game: Node3D = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_flight("spitfire")
	game.enemy.ai.combat_enabled = false
	game.aircraft.pilot.automated = true
	for i in range(5):
		await physics_frame
	# Controlled visual fixture: real component hits, no changes to damage rules.
	game.aircraft.components.apply_damage(&"left_wing", 60)
	game.aircraft.components.apply_damage(&"engine", 25)
	for i in range(4):
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/aircraft-damage-hud.png")
	game.queue_free()
	for i in range(3):
		await physics_frame
	quit()
