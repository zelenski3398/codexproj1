class_name AircraftHangar
extends AirfieldInstallation
## Original sketch-inspired WWII building. Local -Z is the open entrance.
## One damageable static body; open volume is never a solid box collider.
@export var width: float = 48.0
@export var depth: float = 36.0
@export var eaves_height: float = 10.0
@export var ridge_height: float = 16.0
@export var entrance_width: float = 42.0
@export var entrance_height: float = 8.8
@export var truss_spacing: float = 6.0
@export var eaves_projection: float = 0.85
## Floor follows the existing graded apron; walls/steel remain upright.
@export var floor_grade_x: float = 0.0
@export var floor_grade_z: float = 0.0
var truss_count: int = 0
static var _shared_materials: Dictionary = {}
static var _shared_geometry: Dictionary = {}
var _batches: Dictionary = {}
var _materials: Dictionary = {}
var _box_mesh := BoxMesh.new()
var _visuals: Array[MeshInstance3D] = []

func _ready() -> void:
	hp = max_hp
	_box_mesh.size = Vector3.ONE
	name = "AircraftHangar"
	add_to_group("aircraft_hangars")
	size = Vector3(width, ridge_height, depth)
	if _shared_materials.is_empty():
		_shared_materials = {
			"cladding": MeshKit.material(Color("777e7b"), .93),
			"roof": MeshKit.material(Color("858b89"), .88),
			"roof_light": MeshKit.material(Color("929793"), .9),
			"roof_dark": MeshKit.material(Color("767e7d"), .92),
			"steel": MeshKit.material(Color("424d4c"), .78),
			"seams": MeshKit.material(Color("737b78"), .9),
			"rust": MeshKit.material(Color("795c48"), .97),
			"floor": MeshKit.material(Color("7d7b70"), .98),
		}
	_materials = _shared_materials
	for key in ["roof", "roof_light", "roof_dark", "steel", "seams"]:
		_materials[key].metallic = .3
	for key in ["roof_light", "roof_dark", "seams", "rust"]:
		_materials[key].disable_receive_shadows = true
	for key in _materials:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[key] = surface
	_shell()
	_structure()
	_sheets()
	var geometry_key := str([width,depth,eaves_height,ridge_height,entrance_width,entrance_height,truss_spacing,eaves_projection])
	for key in _batches:
		var cache_key: String = geometry_key + String(key)
		var geometry: ArrayMesh
		if key != "floor" and _shared_geometry.has(cache_key):
			geometry = _shared_geometry[cache_key]
		else:
			geometry = _batches[key].commit()
			if key != "floor": _shared_geometry[cache_key] = geometry
		var mesh := MeshKit.mesh(self, geometry, _materials[key])
		mesh.name = String(key).to_pascal_case()
		if key in ["roof_light", "roof_dark", "seams", "rust"]: mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.visibility_range_end = 8000 if key in ["roof", "cladding", "floor"] else (1400 if key == "steel" else 650)
		_visuals.append(mesh)
		if key == "cladding": visual = mesh
	_batches.clear()

func floor_height(x: float, z: float) -> float:
	return floor_grade_x * x + floor_grade_z * z

func _box(dimensions: Vector3, centre: Vector3, material_key: String, basis: Basis = Basis.IDENTITY, solid: bool = false) -> void:
	var pose := Transform3D(basis * Basis.from_scale(dimensions), centre)
	_batches[material_key].append_from(_box_mesh, 0, pose)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collision.shape = shape
		collision.transform = Transform3D(basis, centre)
		add_child(collision)

func _member(a: Vector3, b: Vector3, thickness: float = .18, solid: bool = false) -> void:
	var direction := (b-a).normalized()
	var cross := Vector3.UP.cross(direction)
	var basis := Basis.IDENTITY
	if cross.length_squared() > .000001:
		basis = Basis(cross.normalized(), Vector3.UP.angle_to(direction))
	elif direction.y < 0: basis = Basis(Vector3.RIGHT, PI)
	_box(Vector3(thickness, a.distance_to(b), thickness), (a+b)*.5, "steel", basis, solid)

func _triangle(a: Vector3, b: Vector3, c: Vector3, z: float) -> void:
	# Closed, double-faced triangular masonry/cladding prism, not a transparent decal.
	var vertices := PackedVector3Array()
	for offset in [-.15, .15]:
		for point in [a,b,c]: vertices.append(point+Vector3(0,0,z+offset))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for indices in [[0,2,1],[3,4,5],[0,1,4],[0,4,3],[1,2,5],[1,5,4],[2,0,3],[2,3,5]]:
		var normal := (vertices[indices[1]]-vertices[indices[0]]).cross(vertices[indices[2]]-vertices[indices[0]]).normalized()
		for index in [indices[2],indices[1],indices[0]]:
			surface.set_normal(normal)
			surface.add_vertex(vertices[index])
	# append_from keeps an indexed surface: explicitly index custom triangles
	# too, otherwise only the earlier BoxMesh vertices would render.
	surface.index()
	_batches.cladding.append_from(surface.commit(),0,Transform3D.IDENTITY)
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = vertices
	collision.shape = shape
	add_child(collision)

func _shell() -> void:
	var half := width*.5
	var end := depth*.5
	# Floor top almost flush with terrain; buried lower edge prevents floating foundations.
	var floor_basis := Basis(Vector3.FORWARD, -atan(floor_grade_x)) * Basis(Vector3.RIGHT, -atan(floor_grade_z))
	_box(Vector3(width+.6,.2,depth+3), Vector3(0,-.075,-1.2), "floor", floor_basis, true)
	for side in [-1.0,1.0]:
		_box(Vector3(.35,eaves_height+1,depth),Vector3(side*half,(eaves_height-1)*.5,0),"cladding",Basis.IDENTITY,true)
		var jamb_width := (width-entrance_width)*.5
		_box(Vector3(jamb_width,eaves_height+1,.35),Vector3(side*(half-jamb_width*.5),(eaves_height-1)*.5,-end),"cladding",Basis.IDENTITY,true)
	_box(Vector3(width,eaves_height+1,.35),Vector3(0,(eaves_height-1)*.5,end),"cladding",Basis.IDENTITY,true)
	_box(Vector3(entrance_width,eaves_height-entrance_height,.35),Vector3(0,(eaves_height+entrance_height)*.5,-end),"cladding",Basis.IDENTITY,true)
	for z in [-end,end]:
		_triangle(Vector3(-half,eaves_height,0),Vector3(half,eaves_height,0),Vector3(0,ridge_height,0),z)
	var slope := atan2(ridge_height-eaves_height,half)
	var roof_length := (half+eaves_projection)/cos(slope)
	for side in [-1.0,1.0]:
		var basis := Basis(Vector3.BACK,-side*slope)
		_box(Vector3(roof_length,.18,depth+2*eaves_projection),Vector3(side*(half+eaves_projection)*.5,ridge_height-tan(slope)*(half+eaves_projection)*.5,0),"roof",basis,true)
	# A narrow, galvanized entrance surround makes the genuinely open door
	# readable against its shadowed rear wall without introducing door leaves.
	for side in [-1.0,1.0]:
		_box(Vector3(.24,entrance_height,.18),Vector3(side*(entrance_width*.5+.13),entrance_height*.5,-end-.25),"roof_light")
	_box(Vector3(entrance_width+.5,.24,.18),Vector3(0,entrance_height+.13,-end-.25),"roof_light")
	# Folded ridge cap and fascia have actual thickness.
	_box(Vector3(.6,.16,depth+2*eaves_projection+.2),Vector3(0,ridge_height+.1,0),"seams")

func _structure() -> void:
	var half := width*.5-.4
	var end := depth*.5-.4
	var tie := entrance_height+.35
	var crown := ridge_height-.5
	var edge := eaves_height-.45
	truss_count = maxi(2,int(ceil(depth/maxf(truss_spacing,2)))+1)
	for station in truss_count:
		var z := lerpf(-end,end,float(station)/(truss_count-1))
		# Columns only at the side walls; the full entrance is unsupported at its centre.
		for side in [-1.0,1.0]:
			_member(Vector3(side*half,-.4,z),Vector3(side*half,edge,z),.28,true)
		_member(Vector3(-half,edge,z),Vector3(0,crown,z),.24,true)
		_member(Vector3(0,crown,z),Vector3(half,edge,z),.24,true)
		_member(Vector3(-half,tie,z),Vector3(half,tie,z),.24,true)
		for bay in 8:
			var x := lerpf(-half,half,bay/8.0)
			var next_x := lerpf(-half,half,(bay+1)/8.0)
			var top := lerpf(crown,edge,absf(x)/half)
			var next_top := lerpf(crown,edge,absf(next_x)/half)
			_member(Vector3(x,tie,z),Vector3(x,top,z),.12)
			_member(Vector3(x,tie if bay%2==0 else top,z),Vector3(next_x,next_top if bay%2==0 else tie,z),.14)
		# Wall X bracing in alternate bays, never across the open front.
		if station > 0 and station%2==0:
			var previous_z := lerpf(-end,end,float(station-1)/(truss_count-1))
			for side in [-1.0,1.0]:
				_member(Vector3(side*half,.4,previous_z),Vector3(side*half,edge,z),.13)
				_member(Vector3(side*half,edge,previous_z),Vector3(side*half,.4,z),.13)
	for side in [-1.0,1.0]:
		for section in range(1,6):
			var x: float = side*half*section/5.0
			var y := lerpf(crown,edge,absf(x)/half)
			_member(Vector3(x,y,-end),Vector3(x,y,end),.16)
	for x in [-half,0.0]:
		_member(Vector3(x,.4,end-.05),Vector3(x+half,edge,end-.05),.14)
		_member(Vector3(x,edge,end-.05),Vector3(x+half,.4,end-.05),.14)

func _sheets() -> void:
	var half := width*.5
	var slope := atan2(ridge_height-eaves_height,half)
	var along := (half+eaves_projection)/cos(slope)
	var rows := int(ceil(along/4.0))
	var columns := int(ceil((depth+2*eaves_projection)/3.0))
	for side in [-1.0,1.0]:
		var basis := Basis(Vector3.BACK,-side*slope)
		for row in rows:
			var x: float = side*(half+eaves_projection)*(row+.5)/rows
			for column in columns:
				var z := -depth*.5-eaves_projection+(column+.5)*(depth+2*eaves_projection)/columns
				var key := "roof_light" if (column+row*3)%7==0 else "roof_dark"
				_box(Vector3(along/rows-.035,.025,(depth+2*eaves_projection)/columns-.035),Vector3(x,ridge_height-absf(x)*tan(slope)+.20,z),key,basis)
			# Lap seams run front-to-rear between rows of manageable metal sheets.
			var seam_x: float = side*(half+eaves_projection)*(row+1)/rows
			_box(Vector3(.12,.06,depth+2*eaves_projection),Vector3(seam_x,ridge_height-absf(seam_x)*tan(slope)+.24,0),"seams",basis)
		for column in range(columns+1):
			var z := -depth*.5-eaves_projection+column*(depth+2*eaves_projection)/columns
			_box(Vector3(along,.055,.12),Vector3(side*(half+eaves_projection)*.5,ridge_height-tan(slope)*(half+eaves_projection)*.5+.24,z),"seams",basis)
		# Restrained seam rust; deterministic, no runtime texture dependency.
		for patch in 9:
			var x: float = side*(4+fmod(patch*7.3,half-4))
			_box(Vector3(.13,.03,.4+patch*.06),Vector3(x,ridge_height-absf(x)*tan(slope)+.25,-end_depth()+patch*3.8),"rust",basis)
	# Vertical wall ribs emphasize sheet cladding rather than smooth concrete.
	for side in [-1.0,1.0]:
		for rib in int(depth/2.4):
			_box(Vector3(.07,eaves_height,.12),Vector3(side*(half+.21),eaves_height*.5,-depth*.5+rib*2.4),"seams")

func end_depth() -> float:
	return depth*.5-1

func take_damage(amount: float) -> void:
	var was_destroyed := is_destroyed
	super.take_damage(amount)
	if is_destroyed and not was_destroyed:
		var scorched := MeshKit.material(Color("443c33"))
		for mesh in _visuals: mesh.material_override = scorched
