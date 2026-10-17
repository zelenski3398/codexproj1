extends SceneTree
## Real Compatibility render of geographic fort geometry, not a photo backdrop.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false
	var world:=MaltaWorld.new()
	root.add_child(world)
	for i in range(8):await physics_frame
	var camera:Camera3D=world.fort_battery.reference_camera
	camera.make_current()
	GameAudioMixer.instance.audio_button.hide()
	for label in world.find_children("*","Label3D",true,false):label.hide()
	for light in world.find_children("*","DirectionalLight3D",true,false):
		light.directional_shadow_max_distance=1200 # Reference inspection covers the whole fort.
		light.shadow_bias=.15
		light.shadow_normal_bias=3.0
	var layout:=StElmoLocations.data()
	var center:=Vector3(layout.center_world[0],layout.deck,layout.center_world[1])
	var forward:=Vector3(world.valletta_city.layout.grid_forward_xz[0],0,world.valletta_city.layout.grid_forward_xz[1])
	var point:=StElmoLocations.position_for("st_elmo")
	var views=[
		["st-elmo-north-reference",MaltaGeography.vector(layout.reference_camera.position),MaltaGeography.vector(layout.reference_camera.target)],
		["st-elmo-south-overview",center-forward*280+Vector3(0,180,0),center],
		["st-elmo-courtyard",point-forward*13+Vector3.UP*2,point+forward*14+Vector3.UP*2],
		["st-elmo-bofors",world.fort_battery.guns[0].global_position+Vector3(7,4,9),world.fort_battery.guns[0].global_position+Vector3(0,1.5,0)]]
	for view in views:
		camera.global_position=view[1];camera.look_at(view[2])
		for i in range(6):await process_frame
		await RenderingServer.frame_post_draw
		print("CAPTURE ",view[0]," ",root.get_texture().get_image().save_png("res://docs/previews/"+view[0]+".png"))
	world.queue_free()
	for i in range(4):await process_frame
	quit()
