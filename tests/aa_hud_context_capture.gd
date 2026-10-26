extends SceneTree
func _initialize() -> void:call_deferred("run")
func frames(n: int=10) -> void:
	for i in n:await process_frame
func capture(name: String) -> void:
	await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/aa-hud-context-"+name+".png")
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.start_aa_defence();await frames(40)
	var mission: MaltaMission=game.malta_mission
	var gun: BritishAAGun=game.aa_defence.guns[0]
	mission.pilot.global_position=mission.interaction.find_exit(gun,5);await frames()
	game.gameplay_hud.age=8;await capture("on-foot")
	mission.interaction.mount_gun(gun);await frames()
	await capture("mounted")
	game.gameplay_hud.open_help();await capture("help");game.gameplay_hud.close_help()
	game.queue_free();await frames();quit()
