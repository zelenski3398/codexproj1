class_name MostaRotunda
extends Node3D
## Measured envelope and landmark silhouette. Local +Z is the portico.

var parameters: Dictionary
var foundation_depth: float = .8
var detail: Node3D
var limestone := MeshKit.material(Color("b5a084"))
var moulding := MeshKit.material(Color("c4b095"))
var roof := MeshKit.material(Color("aa9274"))
var dark := MeshKit.material(Color("473c2e"))
var wood := MeshKit.material(Color("4c4938"))
var solid: StaticBody3D

func _ready() -> void:
	name = "MostaRotunda"
	solid = StaticBody3D.new()
	solid.name = "RotundaStructure"
	solid.collision_layer = 1
	solid.collision_mask = 0
	add_child(solid)
	detail = Node3D.new()
	detail.name = "ArchitecturalDetails"
	add_child(detail)
	var radius := float(parameters.drum_diameter) * 0.5
	var spring := float(parameters.dome_spring_height)
	var rise := float(parameters.dome_crown_height) - spring
	var front := float(parameters.front_extent)
	var width := float(parameters.portico_width)
	_round(self, "CircularChurch", radius * .96, radius * .96, -foundation_depth, spring + foundation_depth, limestone, 64)
	_cylinder_collision(radius * .95, spring + foundation_depth, (spring - foundation_depth) * .5)
	for band in [[1.0, 1.4], [11.8, .74], [20.25, .89], [28.7, 1.25]]:
		_round(self, "DrumCornice", radius, radius, band[0], band[1], moulding, 64)
	_dome(radius * .979, spring, rise)
	_round(self, "LanternPlinth", 3.6, 3.8, spring + rise - .5, 1.4, moulding, 24)
	_round(self, "Lantern", 2.55, 2.65, spring + rise + .9, float(parameters.lantern_height) - 2.1, limestone, 24)
	_round(self, "LanternCap", .55, 3.10, spring + rise + float(parameters.lantern_height) - 1.2, 1.7, roof, 24)
	_block(self, "Finial", Vector3(.46, 2.0, .46), Vector3(0,spring+rise+float(parameters.lantern_height)+.65,0), moulding)
	var front_face := front - .85
	var rear_face := front_face - 11.6
	_block(self, "PorticoBackWall", Vector3(width, 21.4, 4.4), Vector3(0,11.0,rear_face-.4), limestone, true)
	_block(self, "RaisedForecourt", Vector3(width+12, 2.7, 22.0), Vector3(0,-.55,front_face-3.5), moulding, true)
	for level in 7:
		var height := float(level+1) * .22
		_block(self, "EntranceStep", Vector3(width+7.3,height,2.2), Vector3(0,height*.5-.52,front_face+10.6-level*.75), moulding, true)
	for i in 6:
		var x := lerpf(-width*.43,width*.43,i/5.0)
		_block(self, "IonicPlinth", Vector3(2.7, .61, 2.7), Vector3(x,1.11,front_face-1.5), moulding, true)
		_round(self, "IonicColumn%02d"%i, .82, 1.02, 1.40, 13.5, moulding, 20).position += Vector3(x,0,front_face-1.5)
		_block(self, "IonicCapital", Vector3(2.34,.90,2.10), Vector3(x,15.0,front_face-1.5), moulding)
		for side in [-1.0,1.0]:
			_round(detail, "CapitalVolute", .28, .28, 14.43, .35, roof, 9).position += Vector3(x+side*.88,0,front_face-.45)
		var column := _cylinder_collision(.98, 13.5, 8.1)
		column.position += Vector3(x, 0, front_face-1.5)
	_block(self, "PorticoEntablature", Vector3(width+2.0, 2.5, 13.2), Vector3(0,16.25,front_face-5.5), limestone, true)
	_block(self, "PorticoCornice", Vector3(width+3.2,.62,13.7), Vector3(0,17.81,front_face-5.5), moulding)
	_pediment(width+3.4, 18.1, 5.2, front_face+1.75, 12.4)
	_block(detail, "CentralEntrance", Vector3(3.4,7.2,.23), Vector3(0,4.71,rear_face+1.84), wood)
	_block(detail, "Lintel", Vector3(4.0,.44,.74), Vector3(0,8.43,rear_face+2.08), moulding)
	for side in [-1.0,1.0]:
		_bell_tower(side * (width*.5+5.3), front_face-8.2)
		_block(detail,"SideDoor",Vector3(2.5,4.25,.24),Vector3(side*7.7,3.3,rear_face+1.84), wood)
	for i in 12:
		var angle := TAU*i/12.0
		var radial := Vector3(sin(angle),0,cos(angle))
		var opening := _block(detail,"DrumRecess",Vector3(2.12,4.7,.24),radial*(radius*.966)+Vector3.UP*24.1,dark)
		opening.rotation.y = angle
		for side in [-1.0,1.0]:
			var jamb := _block(detail,"DrumPilaster",Vector3(.47,5.44,.54),opening.position + Basis(Vector3.UP,angle)*Vector3(side*1.35,0,-.10),moulding)
			jamb.rotation.y = angle

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null: detail.visible = camera.global_position.distance_squared_to(global_position) < 480.0 * 480.0

func _dome(radius: float, spring: float, rise: float) -> void:
	var rings := 19
	# Packed stepped band shells read in grazing light at both flight and walk distance.
	for i in rings:
		var low := PI*.5*i/rings
		var high := PI*.5*(i+1)/rings
		var base := spring + rise*sin(low)
		var height := rise*(sin(high)-sin(low))
		var bottom := radius*cos(low)
		var top := radius*cos(high)
		_round(self,"DomeBand%02d"%i,maxf(top,.15),bottom,base,height+.024,roof if i%3 == 2 else limestone,64)
		if i+1 < rings:
			_round(self,"DomeStep%02d"%i,top+.24,top+.38,base+height-.14,.24,moulding,64)
	# Rounded envelope uses six coarse colliders, independent of the trim.
	for i in 6:
		var low := PI*.5*i/6.0
		var high := PI*.5*(i+1)/6.0
		var bottom := spring+rise*sin(low)
		var top := spring+rise*sin(high)
		_cylinder_collision(radius*cos((low+high)*.5),top-bottom,(bottom+top)*.5)

func _bell_tower(x: float, z: float) -> void:
	_block(self,("BellTowerWest" if x < 0 else "BellTowerEast"),Vector3(7.4,23.0,7.8),Vector3(x,11.5,z),limestone,true)
	for height in [4.0,15.15,21.8,27.0,30.0]:
		_block(self,"TowerCornice",Vector3(8.03,.66,8.42),Vector3(x,height,z),moulding)
	for dx in [-2.8,2.8]:
		for dz in [-2.8,2.8]:
			_block(self,"BelfryPier",Vector3(1.15,7.6,1.15),Vector3(x+dx,25.9,z+dz),moulding,true)
	_block(self,"BelfryShadow",Vector3(5.7,6.2,5.75),Vector3(x,25.8,z),dark)
	_block(self,"BelfryRoof",Vector3(7.4,1.0,7.6),Vector3(x,30.1,z),limestone,true)
	var cap := _round(self,"BellTowerCap",.52,3.8,30.2,4.2,roof,20)
	cap.position += Vector3(x,0,z)
	var clock := _round(detail,"ClockFace",.95,.95,0,.12,dark,24)
	clock.rotation.x = PI*.5
	clock.position = Vector3(x,20.0,z+3.96)
	_block(detail,"ClockHand",Vector3(.07,.60,.08),Vector3(x,20.23,z+4.04),moulding)

func _pediment(width: float, base: float, rise: float, front: float, depth: float) -> void:
	var geometry := SurfaceTool.new()
	geometry.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices := PackedVector3Array([Vector3(-width*.5,base,front),Vector3(width*.5,base,front),Vector3(0,base+rise,front),Vector3(-width*.5,base,front-depth),Vector3(width*.5,base,front-depth),Vector3(0,base+rise,front-depth)])
	for i in [0,2,1,3,4,5,0,3,5,0,5,2,1,2,5,1,5,4,0,1,4,0,4,3]:
		geometry.add_vertex(vertices[i])
	geometry.generate_normals()
	MeshKit.mesh(self,geometry.commit(),limestone).name = "Pediment"
	var shape := ConvexPolygonShape3D.new()
	shape.points = vertices
	_collider(shape,Vector3.ZERO)
	for side in [-1.0,1.0]:
		MeshKit.rod(self,Vector3(side*width*.5,base,front+.047),Vector3(0,base+rise,front+.047),.39,moulding).name = "PedimentRake"

func _block(parent: Node3D, label: String, size: Vector3, point: Vector3, material: Material, collides: bool = false) -> MeshInstance3D:
	var item := MeshKit.box(parent,size,point,material)
	item.name = label
	if collides:
		var shape := BoxShape3D.new()
		shape.size = size
		_collider(shape,point)
	return item

func _round(parent: Node3D, label: String, top: float, bottom: float, y: float, height: float, material: Material, slices: int) -> MeshInstance3D:
	var geometry := CylinderMesh.new()
	geometry.top_radius = top
	geometry.bottom_radius = bottom
	geometry.height = height
	geometry.radial_segments = slices
	var item := MeshKit.mesh(parent,geometry,material,Vector3(0,y+height*.5,0))
	item.name = label
	return item

func _cylinder_collision(radius: float, height: float, y: float) -> CollisionShape3D:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	return _collider(shape,Vector3.UP*y)

func _collider(shape: Shape3D, point: Vector3) -> CollisionShape3D:
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = point
	solid.add_child(collider)
	return collider
