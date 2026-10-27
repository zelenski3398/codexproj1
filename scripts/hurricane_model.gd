class_name HurricaneModel
extends SpitfireModel
## Original metre-scale geometry. Shares the model interface, not Spitfire meshes.
var ailerons: Array[Node3D]=[]
var elevators: Array[Node3D]=[]
var rudder: Node3D
var gear_mix: float=1
var fabric: StandardMaterial3D
func _ready() -> void:
	reference_finish=true
	green=MeshKit.material(Color("48533d"),.86)
	brown=MeshKit.material(Color("756047"),.89)
	underside=MeshKit.material(Color("b3b9a0"),.88)
	fabric=MeshKit.material(Color("68634c"),.95)
	_body()
	for side in [-1.0,1.0]:
		_main_wing(side)
		for x in [2.08,2.43,2.78,3.13]:
			var port:=Marker3D.new();port.name="Browning303_%d"%gun_ports.size()
			port.position=Vector3(side*x,-.07+x*.045,-1.60+(x-1.7)*.2-.035)
			add_child(port);gun_ports.append(port)
			# Flush MG ports and tape patches, no Mk IIc cannon barrels.
			MeshKit.box(self,Vector3(.10,.095,.035),port.position+Vector3(0,0,.02),rubber)
		_roundel(Vector3(side*4.25,.26,.14),.53,false)
		_roundel(Vector3(side*.40,.12,2.25),.36,true)
		var a:=Node3D.new();a.name="LeftAileron" if side<0 else "RightAileron"
		a.position=Vector3(side*4.20,-.10+4.20*.045,.83);add_child(a);ailerons.append(a)
		MeshKit.box(a,Vector3(2.3,.075,.27),Vector3(0,0,.135),green)
		var tail:=Node3D.new();tail.position=Vector3(side*1.05,.12,4.15);add_child(tail)
		_ellipsoid(tail,Vector3(2.2,.14,1.05),Vector3.ZERO,green)
		var e:=Node3D.new();e.name="Elevator"+str(side);e.position=Vector3(side*1.05,.12,4.48);add_child(e);elevators.append(e)
		MeshKit.box(e,Vector3(1.95,.08,.40),Vector3(0,0,.20),green)
		for i in 6:
			MeshKit.box(self,Vector3(.17,.12,.23),Vector3(side*.52,.13,-3.55+i*.25),rubber)
		# Two radiators are not used: Mk I's prominent central radiator is below.
	MeshKit.box(self,Vector3(.93,.51,1.22),Vector3(0,-.67,.68),underside)
	MeshKit.box(self,Vector3(.76,.32,.04),Vector3(0,-.65,.04),rubber)
	for i in 9:MeshKit.rod(self,Vector3(-.33+i*.083,-.79,.01),Vector3(-.33+i*.083,-.51,.01),.007,metal)
	MeshKit.box(self,Vector3(.40,.20,.52),Vector3(0,-.54,-2.65),underside)
	_canopy()
	_fin()
	_propeller_and_gear()
	build_pilot_station(.45,.16)
	for node in find_children("*","MeshInstance3D",true,false):
		node.visibility_range_end=7000
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _body() -> void:
	# z, half width, half height; fuller than the Spitfire, long fabric-covered rear.
	var rings: Array[Vector3]=[Vector3(-4.05,.30,.31),Vector3(-3.7,.48,.51),Vector3(-2.7,.55,.59),Vector3(-1.25,.55,.63),Vector3(-.3,.51,.58),Vector3(.05,.48,.56),Vector3(.95,.43,.52),Vector3(1.3,.40,.60),Vector3(2.2,.31,.51),Vector3(3.5,.19,.35),Vector3(4.6,.095,.20),Vector3(5.16,.035,.08)]
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in rings.size()-1:
		for i in 24:
			var a: float=TAU*i/24;var b: float=TAU*(i+1)/24
			if rings[j].x>=-.3 and rings[j+1].x<=1.3 and cos((a+b)*.5)>.45:continue
			var r: Vector3=rings[j];var n: Vector3=rings[j+1]
			var points: Array[Vector3]=[Vector3(sin(a)*r.y,cos(a)*r.z,r.x),Vector3(sin(b)*r.y,cos(b)*r.z,r.x),Vector3(sin(a)*n.y,cos(a)*n.z,n.x),Vector3(sin(b)*n.y,cos(b)*n.z,n.x)]
			var color: Color=underside.albedo_color if cos((a+b)*.5)<-.35 else (brown.albedo_color if sin(a)*.8+sin(r.x*1.3)>.1 else green.albedo_color)
			for k in [0,1,2,1,3,2]:tool.set_color(color);tool.add_vertex(points[k])
	tool.generate_normals()
	var mat:=MeshKit.material(Color.WHITE);mat.vertex_color_use_as_albedo=true
	MeshKit.mesh(self,tool.commit(),mat).name="HurricaneFuselage"
	# Restrained raised stringers make the aft fabric contours readable.
	for side in [-1.0,1.0]:
		for level in [-.5,0,.5]:
			for j in range(7,rings.size()-1):
				var r: Vector3=rings[j];var n: Vector3=rings[j+1]
				MeshKit.rod(self,Vector3(side*r.y*.91,level*r.z,r.x),Vector3(side*n.y*.91,level*n.z,n.x),.008,fabric)

func _main_wing(side: float) -> void:
	var sections: Array[Vector3]=[Vector3(.40,-1.65,1.10),Vector3(1.7,-1.60,1.08),Vector3(3.6,-1.22,1.02),Vector3(5.3,-.70,.91),Vector3(5.86,-.20,.72),Vector3(6.095,.28,.38)]
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in sections.size()-1:
		for i in 16:
			var points: Array[Vector3]=[]
			for row in [sections[j],sections[j+1]]:
				for step in [i,i+1]:
					var angle: float=TAU*step/16
					var chord: float=row.z-row.y
					points.append(Vector3(side*row.x,-.10+row.x*.045+sin(angle)*chord*.065,lerpf(row.y,row.z,(1-cos(angle))*.5)))
			for k in ([0,1,2,1,3,2] if side>0 else [0,2,1,1,2,3]):
				var p: Vector3=points[k]
				tool.set_color(underside.albedo_color if i>=8 else (brown.albedo_color if p.z>sin(absf(p.x)*1.4)*.55-.2 else green.albedo_color));tool.add_vertex(p)
	tool.generate_normals()
	var mat:=MeshKit.material(Color.WHITE);mat.vertex_color_use_as_albedo=true;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	MeshKit.mesh(self,tool.commit(),mat).name="LeftWing" if side<0 else "RightWing"

func _canopy() -> void:
	var glass:=MeshKit.material(Color(.30,.44,.47,.17),.25)
	glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	MeshKit.box(self,Vector3(.76,.63,1.30),Vector3(0,.86,.45),glass)
	for z in [-.2,.15,.55,.95,1.10]:
		MeshKit.rod(self,Vector3(-.39,.55,z),Vector3(-.32,1.19,z),.019,green)
		MeshKit.rod(self,Vector3(-.32,1.19,z),Vector3(.32,1.19,z),.019,green)
		MeshKit.rod(self,Vector3(.32,1.19,z),Vector3(.39,.55,z),.019,green)
	for x in [-.34,.34]:MeshKit.rod(self,Vector3(x,1.19,-.2),Vector3(x,1.19,1.10),.019,green)
	MeshKit.rod(self,Vector3(0,.60,1.45),Vector3(0,1.72,1.45),.018,metal)
	MeshKit.rod(self,Vector3(0,1.72,1.45),Vector3(0,1.7,4.7),.004,rubber)

func _fin() -> void:
	# The fixed fin and separate trailing rudder have an upright rounded outline.
	_ellipsoid(self,Vector3(.15,2.04,1.18),Vector3(0,1.04,4.59),green)
	rudder=Node3D.new();rudder.name="Rudder";rudder.position=Vector3(0,.15,4.94);add_child(rudder)
	_ellipsoid(rudder,Vector3(.16,1.77,.78),Vector3(0,.91,.06),brown)
	for side in [-1.0,1.0]:
		for i in 3:MeshKit.box(self,Vector3(.016,.74,.17),Vector3(side*.085,1.20,4.36+i*.17),MeshKit.material([Color("953c32"),Color("dddcc5"),Color("263e58")][i]))

func _propeller_and_gear() -> void:
	propeller=Node3D.new();propeller.position=Vector3(0,0,-4.0);add_child(propeller)
	_ellipsoid(propeller,Vector3(.66,.66,.60),Vector3(0,0,-.15),brown)
	for i in 3:
		var blade:=Node3D.new();blade.rotation.z=TAU*i/3;propeller.add_child(blade)
		_ellipsoid(blade,Vector3(.20,1.19,.07),Vector3(0,.79,0),rubber)
		MeshKit.box(blade,Vector3(.12,.12,.072),Vector3(0,1.34,0),MeshKit.material(Color("c1ab61")))
	for i in 3:
		var root:=Node3D.new();root.name="MainWheel"+str(i) if i<2 else "Tailwheel";add_child(root);wheel_roots.append(root)
		var tyre:=MeshKit.cylinder(root,.32 if i<2 else .18,.21 if i<2 else .12,Vector3.ZERO,rubber);tyre.rotation.z=PI/2
		var hub:=MeshKit.cylinder(root,.13 if i<2 else .08,.22 if i<2 else .13,Vector3.ZERO,metal);hub.rotation.z=PI/2
		struts.append(MeshKit.cylinder(self,.055,.5,Vector3.ZERO,metal))

func animate(delta: float,throttle: float,gear: LandingGear,broken: bool) -> void:
	var plane: FlightAircraft=get_parent() as FlightAircraft
	var running: bool=plane.engine_running if plane!=null else throttle>0
	if not broken and running:propeller.rotation.z+=delta*(24+throttle*85)*float(engine_factors.get(0,1))
	gear_mix=move_toward(gear_mix,1 if gear.extended else 0,delta*.65)
	for i in 3:
		var length: float=gear.travel[i]-gear.compression[i]
		var extended: Vector3=gear.anchors[i]+Vector3.DOWN*length
		wheel_roots[i].position=extended if i==2 else Vector3(signf(extended.x)*.65,-.15,extended.z).lerp(extended,gear_mix)
		wheel_roots[i].visible=i==2 or gear_mix>.01
		struts[i].visible=wheel_roots[i].visible
		var mount: Vector3=Vector3(signf(extended.x)*2.25,-.10,-1.05) if i<2 else Vector3(0,-.10,4.65)
		var offset: Vector3=wheel_roots[i].position-mount
		struts[i].position=mount+offset*.5;struts[i].scale.y=maxf(offset.length(),.01)/.5
		struts[i].quaternion=Quaternion(Vector3.UP,offset.normalized()) if offset.length_squared()>.000001 else Quaternion.IDENTITY
	if plane!=null:
		for i in ailerons.size():ailerons[i].rotation.x=lerpf(ailerons[i].rotation.x,plane.pilot.roll*(1 if i==0 else -1)*.30*plane.components.roll_factor(plane.pilot.roll),minf(delta*9,1))
		for elevator in elevators:elevator.rotation.x=lerpf(elevator.rotation.x,plane.pilot.pitch*.3*plane.components.elevator_factor(),minf(delta*9,1))
		rudder.rotation.y=lerpf(rudder.rotation.y,plane.pilot.rudder*.35*plane.components.rudder_factor(),minf(delta*9,1))

func _ellipsoid(parent: Node3D,dimensions: Vector3,point: Vector3,material: Material) -> MeshInstance3D:
	var mesh:=SphereMesh.new();mesh.radius=.5;mesh.height=1;mesh.radial_segments=20;mesh.rings=10
	var visual:=MeshKit.mesh(parent,mesh,material,point);visual.scale=dimensions;return visual
