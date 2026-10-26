class_name MalteseTrees
extends Node3D
## Baked, reproducible placements; shared meshes/opaque material, spatial LOD.
const PLACEMENTS := "res://assets/malta/countryside/trees.json"
var layout: Dictionary
var models: Dictionary
var meshes: Dictionary = {}
var material: StandardMaterial3D
var instance_count: int = 0
var batch_count: int = 0
var collider_count: int = 0
var collision_bodies: Dictionary = {}
var placement_cells: Dictionary = {}
var refresh_clock: float = 0
@export var near_distance: float = 380
@export var far_distance: float = 2200
@export var collision_distance: float = 220
@export var maximum_colliders: int = 192

func _ready() -> void:
	name="MalteseTrees"
	layout=JSON.parse_string(FileAccess.get_file_as_string(PLACEMENTS))
	models=JSON.parse_string(FileAccess.get_file_as_string(layout.models))
	near_distance=float(layout.settings.near_distance_m);far_distance=float(layout.settings.far_distance_m)
	collision_distance=float(layout.settings.collision_distance_m);maximum_colliders=int(layout.settings.maximum_trunk_colliders)
	material=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true;material.roughness=1
	var grouped: Dictionary={}
	for i in layout.trees.size():
		var tree: Dictionary=layout.trees[i]
		var point:=MaltaGeography.vector(tree.position)
		var cell:=Vector2i(floori(point.x/float(layout.settings.batch_size_m)),floori(point.z/float(layout.settings.batch_size_m)))
		var key: String="%d_%d_%s_%d"%[cell.x,cell.y,tree.species,int(tree.variant)]
		if not grouped.has(key):grouped[key]=[]
		grouped[key].append(i)
		var collision_cell:=Vector2i(floori(point.x/collision_distance),floori(point.z/collision_distance))
		if not placement_cells.has(collision_cell):placement_cells[collision_cell]=[]
		placement_cells[collision_cell].append(i)
		instance_count+=1
	for key in grouped:
		var indices: Array=grouped[key]
		var tree: Dictionary=layout.trees[indices[0]]
		var origin:=Vector3.ZERO
		for index in indices:origin+=MaltaGeography.vector(layout.trees[index].position)/indices.size()
		for lod in ["near","far"]:
			var mesh: Mesh=_mesh(tree.species,int(tree.variant),lod)
			var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=mesh;multi.instance_count=indices.size()
			for j in indices.size():
				var item: Dictionary=layout.trees[indices[j]]
				var pose:=Transform3D(Basis(Vector3.UP,float(item.yaw)).scaled(Vector3.ONE*float(item.scale)),MaltaGeography.vector(item.position)-origin)
				multi.set_instance_transform(j,pose)
			var batch:=MultiMeshInstance3D.new();batch.multimesh=multi;batch.position=origin
			batch.material_override=material;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.visibility_range_begin=0 if lod=="near" else near_distance
			batch.visibility_range_end=near_distance if lod=="near" else far_distance
			# Same origin/range boundary: no overlapping full trees or alpha fades.
			batch.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			batch.name="%s_%s"%[key,lod];add_child(batch);batch_count+=1

func _mesh(species: String,variant: int,lod: String) -> Mesh:
	var key: String="%s_%d_%s"%[species,variant,lod]
	if meshes.has(key):return meshes[key]
	var source: Node3D=load(models.species[species][variant][lod]).instantiate()
	var nodes:=source.find_children("*","MeshInstance3D",true,false)
	var mesh: Mesh=nodes[0].mesh if not source is MeshInstance3D else source.mesh
	meshes[key]=mesh;source.free();return mesh

func _process(delta: float) -> void:
	refresh_clock+=delta
	if refresh_clock<.5:return
	refresh_clock=0
	var camera:=get_viewport().get_camera_3d()
	if camera!=null:refresh_collisions(camera.global_position)

func refresh_collisions(listener: Vector3) -> void:
	# Spatial lookup and a strict body cap; never scan all trees each frame.
	var cell:=Vector2i(floori(listener.x/collision_distance),floori(listener.z/collision_distance))
	var nearby: Array=[]
	for x in range(cell.x-1,cell.x+2):
		for z in range(cell.y-1,cell.y+2):
			for index in placement_cells.get(Vector2i(x,z),[]):
				var distance: float=listener.distance_to(MaltaGeography.vector(layout.trees[index].position))
				if distance<collision_distance:nearby.append({"index":index,"distance":distance})
	nearby.sort_custom(func(a,b):return a.distance<b.distance)
	var wanted: Dictionary={}
	for candidate in nearby.slice(0,maximum_colliders):wanted[candidate.index]=true
	for index in collision_bodies.keys():
		if not wanted.has(index):collision_bodies[index].queue_free();collision_bodies.erase(index)
	for index in wanted:
		if collision_bodies.has(index):continue
		var tree: Dictionary=layout.trees[index]
		var model: Dictionary=models.species[tree.species][int(tree.variant)]
		var body:=StaticBody3D.new();body.name="TreeTrunk_%d"%index;body.collision_layer=1;body.collision_mask=0
		var shape:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new()
		cylinder.radius=float(model.trunk_radius)*float(tree.scale)
		cylinder.height=float(model.trunk_collision_height)*float(tree.scale)
		shape.shape=cylinder;shape.position.y=cylinder.height*.5;body.add_child(shape)
		body.position=MaltaGeography.vector(tree.position);add_child(body);collision_bodies[index]=body
	collider_count=collision_bodies.size()
