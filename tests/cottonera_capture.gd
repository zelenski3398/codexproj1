extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	var review: Node3D=load("res://scenes/cottonera_asset_review.tscn").instantiate();root.add_child(review)
	GameAudioMixer.instance.audio_button.visible=false
	for i in range(6):await process_frame
	await RenderingServer.frame_post_draw
	print("CAPTURE UNPLACED TEMPLATES ",root.get_texture().get_image().save_png("res://docs/previews/cottonera-unplaced-templates.png"))
	review.queue_free();await process_frame;quit()
