extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := MaltaWorld.new()
	root.add_child(world)
	for i in range(12): await process_frame
	GameAudioMixer.instance.audio_button.hide()
	var camera := Camera3D.new()
	camera.far=100000
	world.add_child(camera)
	camera.make_current()
	var paths: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/malta/roads/world_paths.json"))
	var screenshots := {"road-overhead": [Vector3(2500,12000,6500),Vector3(2500,0,6500)], "road-network-close": [Vector3(2500,2200,6500),Vector3(2500,0,6500)]}
	for id in ["access_ta_qali","access_luqa","access_hal_far"]:
		for path in paths.paths:
			if path.id!=id: continue
			var i:int=mini(18,path.points.size()-2)
			var p:Array=path.points[i]
			var n:Array=path.points[mini(i+8,path.points.size()-1)]
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p[0],500,p[1]),Vector3(p[0],0,p[1]),1))
			var centre:=Vector3(p[0],float(hit.position.y) if not hit.is_empty() else 100.0,p[1])
			var direction:Vector3=Vector3(n[0]-p[0],0,n[1]-p[1]).normalized()
			screenshots["road-"+id]=[centre+Vector3.UP*2-direction*9,centre+direction*35+Vector3.UP*1]
	for key in screenshots:
		camera.global_position=screenshots[key][0]
		camera.look_at(screenshots[key][1],Vector3.FORWARD if key in ["road-overhead","road-network-close"] else Vector3.UP)
		for i in range(8):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/previews/"+key+".png")
	quit()
