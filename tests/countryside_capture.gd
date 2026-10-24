extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	var world:=MaltaWorld.new(); root.add_child(world)
	for i in range(5): await physics_frame
	var rural: MaltaCountryside=world.countryside
	var camera:=Camera3D.new();camera.near=.15;camera.far=40000;camera.fov=53
	world.add_child(camera);camera.make_current()
	for label in world.find_children("*","Label3D",true,false):label.visible=false
	GameAudioMixer.instance.audio_button.visible=false
	var chosen:Dictionary
	for cluster in rural.manifest.clusters:
		if cluster.centre[2]>0 and (chosen.is_empty() or cluster.plots>chosen.plots):chosen=cluster
	var centre:=MaltaGeography.vector(chosen.centre)
	var nearest:Dictionary=rural.manifest.sections[0]
	var distance:float=INF
	for section in rural.manifest.sections:
		var middle:Vector3=(MaltaGeography.vector(section.a)+MaltaGeography.vector(section.b))*.5
		if middle.distance_to(centre)<distance:distance=middle.distance_to(centre);nearest=section
	var a:=MaltaGeography.vector(nearest.a);var b:=MaltaGeography.vector(nearest.b)
	var middle:Vector3=(a+b)*.5
	var normal:=Vector3(b.z-a.z,0,a.x-b.x).normalized()
	var ground_camera:Vector3=middle+normal*5+(b-a).normalized()*2
	var hit:Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(ground_camera.x,500,ground_camera.z),Vector3(ground_camera.x,-50,ground_camera.z),1))
	ground_camera.y=(hit.position.y if not hit.is_empty() else middle.y)+1.65
	var views:Array=[
		["countryside-expanded-fields-aerial",centre+Vector3(170,260,230),centre],
		["countryside-expanded-rubble-ground",ground_camera,middle+Vector3.UP*.5],
		["countryside-expanded-regional",centre+Vector3(900,850,1200),centre+Vector3(-500,0,-500)]
	]
	for view in views:
		camera.global_position=view[1];camera.look_at(view[2])
		for i in range(8 if "--quick" in OS.get_cmdline_user_args() else 50):
			rural.refresh_detail(camera.global_position)
			await process_frame
		await RenderingServer.frame_post_draw
		print("CAPTURE ",view[0]," ",root.get_texture().get_image().save_png("res://docs/previews/"+view[0]+".png"))
		if "--quick" in OS.get_cmdline_user_args(): break
	world.queue_free()
	for i in range(4):await process_frame
	quit()
