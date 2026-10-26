extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	GameAudioMixer.instance.playback_enabled=false;GameAudioMixer.instance.audio_button.hide()
	var stage:=Node3D.new();root.add_child(stage)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("afc5c7")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("d3d8c9");environment.environment.ambient_light_energy=.65
	stage.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.2;stage.add_child(sun)
	MeshKit.box(stage,Vector3(70,.12,65),Vector3(0,-.08,0),MeshKit.material(Color("91896d")))
	var model_material:=StandardMaterial3D.new();model_material.vertex_color_use_as_albedo=true;model_material.vertex_color_is_srgb=true;model_material.roughness=1
	var camera:=Camera3D.new();camera.far=200;camera.fov=52;stage.add_child(camera);camera.make_current()
	var groups: Array=[]
	for species in ["carob","olive","aleppo_pine"]:
		var group:=Node3D.new();stage.add_child(group);groups.append(group)
		for variant in 3:
			var tree: Node3D=load("res://assets/malta/vegetation/%s_%d_near.glb"%[species,variant]).instantiate()
			group.add_child(tree);tree.position=Vector3((variant-1)*13,0,0)
			for mesh in tree.find_children("*","MeshInstance3D",true,false):mesh.material_override=model_material
		group.hide()
	for i in groups.size():
		groups[i].show();camera.position=Vector3(12,9,32);camera.look_at(Vector3(0,4.2,0))
		for frame in 6:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/previews/maltese-trees-%s.png"%["carob","olive","aleppo-pine"][i])
		groups[i].hide()
	stage.queue_free();for frame in 4:await process_frame
	quit()
