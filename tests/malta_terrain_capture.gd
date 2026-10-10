extends SceneTree
## Native rendered review: actual Luqa mission plus fixed terrain overview.
## Requires a graphical display; no aircraft positions/physics are assigned.
var output: String

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	GameAudioMixer.instance.playback_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	output = args[0] if not args.is_empty() else "/tmp/malta-terrain-review"
	DirAccess.make_dir_recursive_absolute(output)
	var game: Node3D = preload("res://main.tscn").instantiate()
	root.add_child(game)
	for frame in range(4):
		await process_frame
	game.start_malta("luqa", "spitfire")
	for frame in range(120):
		await physics_frame
	paused = true
	await _capture("native-luqa-normal")
	print("NATIVE TERRAIN NORMAL ", JSON.stringify(game.field.terrain_appearance.diagnostic_state()))
	game.field.terrain_appearance.set_debug_heatmap(true)
	await _capture("native-luqa-heatmap")
	game.field.terrain_appearance.set_debug_heatmap(false)
	# Overview camera is confined to this review fixture, never mission code.
	var camera: Camera3D = Camera3D.new()
	# This high-altitude review needs a sensible near plane for depth precision.
	camera.near = 10.0
	camera.far = 100000
	camera.fov = 55
	game.add_child(camera)
	camera.position = Vector3(19000, 16000, 23000)
	camera.look_at(Vector3(1000, 0, 0))
	camera.make_current()
	game.malta_mission.status.visible = false
	await _capture("native-overview-normal")
	game.field.terrain_appearance.set_debug_heatmap(true)
	await _capture("native-overview-heatmap")
	game.field.terrain_appearance.set_debug_heatmap(false)
	game.queue_free()
	paused = false
	for frame in range(8):
		await process_frame
	quit()

func _capture(label: String) -> void:
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	print("CAPTURE ", label, " result=", result)
