extends SceneTree
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await process_frame
func capture(name: String) -> void:
	await frames(5);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/minimal-hud-"+name+".png")
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.start_test_departure("sea_gladiator");await frames(40)
	game.gameplay_hud.age=8
	await capture("free-roam")
	game.malta_mission.board_nearest();await frames(20);game.gameplay_hud.age=8
	await capture("aircraft")
	game.gameplay_hud.open_help();await capture("help");game.gameplay_hud.close_help()
	game.show_selection(false);game.start_malta("ta_qali","spitfire","aa_defence",true);await frames(40)
	await capture("defence")
	root.content_scale_size=Vector2i(960,600);root.size=Vector2i(960,600);await frames(10)
	await capture("small")
	game.gameplay_hud.open_help();await capture("help-small");game.gameplay_hud.close_help()
	game.queue_free();await frames(5);quit()
