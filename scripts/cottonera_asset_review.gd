extends Node3D
## F6 review scene only. These display cells are NOT geographic Malta locations.
func _ready() -> void:
	var scene: Node3D=preload("res://assets/malta/cottonera/templates/architecture.glb").instantiate()
	add_child(scene)
	var material:=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true;material.albedo_color=Color(.72,.72,.72);material.roughness=.95
	for mesh in scene.find_children("*","MeshInstance3D",true,false):mesh.material_override=material
	MeshKit.box(self,Vector3(600,1,600),Vector3(130,-.6,30),MeshKit.material(Color(.25,.28,.24)))
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-32,0);add_child(sun)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.45,.61,.68);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color(.7,.75,.8);environment.environment.ambient_light_energy=.4;add_child(environment)
	var camera:=Camera3D.new();camera.far=5000;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=420;add_child(camera);camera.position=Vector3(450,330,430);camera.look_at(Vector3(130,0,20));camera.make_current()
	var gallery: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/malta/cottonera/templates/gallery.json"))
	for record in gallery.templates:
		var label:=Label3D.new();label.text=record.name;label.position=Vector3(record.display_xz[0],35,record.display_xz[1]);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.font_size=28;label.pixel_size=.2;add_child(label)
	var canvas:=CanvasLayer.new();add_child(canvas)
	var title:=Label.new();title.text="COTTONERA — UNPLACED ASSET TEMPLATES\nSchematic architecture only; NOT a mapped or surveyed Three Cities reconstruction";title.position=Vector2(24,20);title.add_theme_font_size_override("font_size",22);canvas.add_child(title)
