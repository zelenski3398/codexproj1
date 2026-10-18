extends SceneTree
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func capture(camera: Camera3D, hangar: AircraftHangar, filename: String, eye: Vector3, target: Vector3) -> void:
	camera.global_position=hangar.to_global(eye)
	camera.look_at(hangar.to_global(target))
	await frames(8)
	await RenderingServer.frame_post_draw
	print("CAPTURE ",filename,": ",root.get_texture().get_image().save_png("res://docs/previews/"+filename+".png"))
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	var world := MaltaWorld.new()
	root.add_child(world)
	await frames(10)
	GameAudioMixer.instance.audio_button.hide()
	for label in world.find_children("*","Label3D",true,false): label.hide()
	var camera := Camera3D.new()
	camera.fov=55
	camera.far=4000
	camera.near=1.0
	world.add_child(camera)
	camera.make_current()
	var hangar: AircraftHangar=world.fields.ta_qali.installations[0]
	# Preview-only models demonstrate the actual aircraft dimensions; mission
	# parking/spawning is deliberately unchanged.
	for slot in [-14.0,0.0,14.0]:
		var aircraft: SpitfireModel=SeaGladiatorModel.new() if slot==0 else SpitfireModel.new()
		hangar.add_child(aircraft)
		aircraft.position=Vector3(slot,hangar.floor_height(slot,2)+1.2,2)
		aircraft.rotation.x=.117
		var gear := LandingGear.new()
		aircraft.animate(0,0,gear,false)
		gear.free()
	await frames(6)
	await capture(camera,hangar,"hangar-front",Vector3(-32,12,-62),Vector3(0,7,0))
	await capture(camera,hangar,"hangar-interior",Vector3(16,3,-15),Vector3(-6,8,7))
	for id in world.fields:
		var field: MaltaAirfield=world.fields[id]
		var anchor: AircraftHangar=field.installations[0]
		await capture(camera,anchor,"hangar-"+id+"-aerial",Vector3(-150,130,-180),Vector3(20,0,-45))
	world.queue_free()
	await frames(12)
	RenderingServer.force_sync()
	quit()
