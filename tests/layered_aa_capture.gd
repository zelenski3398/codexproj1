extends SceneTree
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in range(n):await process_frame
func run() -> void:
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	game.start_malta("luqa","spitfire","aa_defence")
	await frames(20)
	var battery: AirfieldAABattery=game.field.aa_battery
	var field: MaltaAirfield=game.field.fields.luqa
	game.malta_mission.canvas.hide()
	game.aa_defence.canvas.hide()
	var camera:=Camera3D.new()
	game.add_child(camera)
	camera.make_current()
	for spec in [[0,"layered-aa-heavy"],[4,"layered-aa-bofors"]]:
		var gun: BritishAAGun=game.aa_defence.guns[spec[0]]
		camera.global_position=gun.global_position+field.global_basis*Vector3(7,4,8)
		camera.look_at(gun.global_position+Vector3.UP*1.5)
		await frames(8)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/previews/"+spec[1]+".png")
	quit()
