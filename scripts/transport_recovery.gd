class_name TransportRecovery
extends Node
## One request/truck per human life. Only an explicit E entry starts return.
@export var response_seconds: float = 6.0
@export var fade_seconds: float = .65
@export var approach_speed: float = 3.0
static var road_points: PackedVector2Array = PackedVector2Array()
var mission: MaltaMission
var state: String = "IDLE"
var clock: float = 0
var truck: MilitaryTruck
var pontoon: StaticBody3D
var destination: String = ""
var pickup: Vector3
var arrival_goal: Vector3
var return_point: Vector3
var fade: ColorRect
var status: Label
var requests: int = 0
var returns: int = 0
func _ready() -> void:
	status=Label.new()
	status.position=Vector2(32,225)
	status.add_theme_font_size_override("font_size",19)
	mission.canvas.add_child(status)
	fade=ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color=Color(0,0,0,0)
	fade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	mission.canvas.add_child(fade)
func available() -> bool:
	if not mission.survival.alive() or mission.interaction.is_operating():return false
	var aircraft: FlightAircraft=mission.occupied
	if is_instance_valid(aircraft):return aircraft.is_destroyed or aircraft.is_crashed
	if is_instance_valid(mission.last_abandoned) and mission.pilot.global_position.distance_to(mission.last_abandoned.global_position)<60:return true
	# A healthy pilot can request help away from any base, or beside a wreck.
	for field in mission.world.fields.values():
		if field.contains(mission.pilot.global_position):return false
	return true
func request() -> bool:
	if state!="IDLE" or not available() or get_tree().paused:return false
	destination=mission.survival.departure_airfield
	if not mission.world.fields.has(destination):destination=mission.home
	state="REQUESTED"
	clock=response_seconds
	requests+=1
	mission._message("Transport requested · exit the wreck when safe, then approach the truck")
	return true
func _physics_process(delta: float) -> void:
	if get_tree().paused:return
	if not mission.survival.alive():
		_clear_pickup()
		state="IDLE"
		fade.color.a=0
		return
	if state=="REQUESTED":
		clock-=delta
		if clock<=0:_arrive()
	elif state=="ARRIVING":
		var offset: Vector3=(arrival_goal-truck.global_position)*Vector3(1,0,1)
		if offset.length()<.4:
			state="READY"
			truck.set_physics_process(true)
		else:
			var collision:=truck.move_and_collide(offset.normalized()*minf(offset.length(),approach_speed*delta))
			if collision!=null:state="READY";truck.set_physics_process(true)
	elif state=="RETURNING":
		clock+=delta
		fade.color.a=clampf(clock/maxf(fade_seconds,.01),0,1)
		if clock>=fade_seconds:_return_home()
	elif state=="FADING_IN":
		clock+=delta
		fade.color.a=1-clampf(clock/maxf(fade_seconds,.01),0,1)
		if clock>=fade_seconds:state="IDLE";fade.mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:
	var hint: String=""
	if state=="IDLE" and available():hint="V Call transport assistance"
	elif state=="REQUESTED":hint="Transport requested · arriving in %.0f s"%maxf(clock,0)
	elif state=="ARRIVING":hint="Truck arriving · wait beside the pickup"
	elif state=="READY" and is_instance_valid(truck):
		var anchor: Vector3=mission.occupied.global_position if is_instance_valid(mission.occupied) else mission.pilot.global_position
		var delta_position:=truck.global_position-anchor
		var bearing:=fposmod(rad_to_deg(atan2(delta_position.x,-delta_position.z)),360)
		hint="Enter truck to return to %s · %d m · bearing %03d°\n%s"%[mission.world.fields[destination].record.name,roundi(delta_position.length()),roundi(bearing),"Exit wreck with E, then approach pickup" if mission.occupied!=null else "Approach truck · E Return to base"]
		if pontoon!=null:hint+="\nSea rescue · truck waits above water on a rescue pontoon"
	elif state in ["RETURNING","FADING_IN"]:hint="Returning to base · battle continues"
	status.text=hint
func _origin() -> Vector3:
	return mission.occupied.global_position if is_instance_valid(mission.occupied) else mission.pilot.global_position
func _dry_pose(point: Vector3) -> Transform3D:
	var space:=mission.world.get_world_3d().direct_space_state
	var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x,1000,point.z),Vector3(point.x,-50,point.z),1))
	if hit.is_empty() or hit.collider.is_in_group("aircraft_water") or hit.normal.y<.94:return Transform3D(Basis.IDENTITY,Vector3.INF)
	# A flat roof is not a drivable pickup site. Use the actual ground/road
	# colliders, not city roofs, hangars, vehicles or the abandoned airframe.
	if not hit.collider.is_in_group("terrain") and not String(hit.collider.get_parent().name).begins_with("RoadGround"):return Transform3D(Basis.IDENTITY,Vector3.INF)
	var centre: Vector3=hit.position+Vector3.UP*.06
	var direction:=(_origin()-centre)*Vector3(1,0,1)
	if direction.length_squared()<1:direction=Vector3.FORWARD
	var basis:=Basis.looking_at(direction.normalized())
	var shape:=BoxShape3D.new()
	shape.size=Vector3(2.5,2.5,5.2)
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.transform=Transform3D(basis,centre+Vector3.UP*1.4)
	query.collision_mask=31
	if not space.intersect_shape(query).is_empty():return Transform3D(Basis.IDENTITY,Vector3.INF)
	# A centre ray alone would let a truck overhang a cliff or wall.
	for offset in [Vector3(-1,0,-2.3),Vector3(1,0,-2.3),Vector3(-1,0,2.3),Vector3(1,0,2.3)]:
		var corner: Vector3=centre+basis*offset
		var support:=space.intersect_ray(PhysicsRayQueryParameters3D.create(corner+Vector3.UP,corner-Vector3.UP*2,1))
		if support.is_empty() or support.collider.is_in_group("aircraft_water") or absf(support.position.y-centre.y)>.3:return Transform3D(Basis.IDENTITY,Vector3.INF)
	return Transform3D(basis,centre)
func _arrive() -> void:
	if state!="REQUESTED":return
	var origin:=_origin()
	var candidates: Array[Vector3]=[]
	# Read the existing mapped road network once; no new routing/GIS data.
	if road_points.is_empty():
		var network: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/malta/roads/world_paths.json"))
		for road in network.get("paths",[]):
			for point in road.points:road_points.append(Vector2(point[0],point[1]))
	for point in road_points:
		if point.distance_to(Vector2(origin.x,origin.z))<100:candidates.append(Vector3(point.x,0,point.y))
	# Prefer a nearby existing road access point, followed by local open ground.
	for field in mission.world.fields.values():
		# Painted internal driving lanes are valid road pickup sites too. The
		# exterior road join can otherwise add an unnecessary 50–100 m walk.
		var local: Vector3=field.to_local(origin)
		for lane in field.access_record.get("lanes",[]):
			var a:=Vector2(lane.from[0],lane.from[1])
			var b:=Vector2(lane.to[0],lane.to[1])
			var closest:=Geometry2D.get_closest_point_to_segment(Vector2(local.x,local.z),a,b)
			var candidate: Vector3=field.to_global(Vector3(closest.x,0,closest.y))
			if candidate.distance_to(origin)<100:candidates.append(candidate)
		for point in field.access_record.get("exterior_points",[]):
			var candidate:=Vector3(point[0],0,point[1])
			if ((candidate-origin)*Vector3(1,0,1)).length()<100:candidates.append(candidate)
	candidates.sort_custom(func(a,b):return a.distance_squared_to(origin)<b.distance_squared_to(origin))
	for radius in [12.0,22.0,38.0,65.0,100.0]:
		for step in 16:candidates.append(origin+Vector3(cos(step*TAU/16),0,sin(step*TAU/16))*radius)
	var pose:=Transform3D(Basis.IDENTITY,Vector3.INF)
	for point in candidates:
		pose=_dry_pose(point)
		if pose.origin.is_finite():break
	if not pose.origin.is_finite():
		# Sea/inaccessible coast: the truck arrives on a small rescue pontoon,
		# not on the seabed. The living pilot can swim up and explicitly enter.
		var sea_pose:=_sea_pickup(origin)
		if sea_pose.is_finite():
			_create_pontoon(sea_pose)
			pose=Transform3D(Basis.IDENTITY,sea_pose+Vector3.UP*.45)
		else:
			# An accessible base pickup remains available; report bearing/distance.
			var fallback: Array[Vector3]=[]
			for field in mission.world.fields.values():
				fallback.append(field.to_global(Vector3(78,0,field.runway_length*.31+45)))
				fallback.append(field.to_global(Vector3(78,0,field.runway_length*.31-75)))
			fallback.sort_custom(func(a,b):return a.distance_squared_to(origin)<b.distance_squared_to(origin))
			for point in fallback:
				pose=_dry_pose(point)
				if pose.origin.is_finite():break
	if not pose.origin.is_finite():
		clock=2 # retry while the world keeps running; never insert overlapping geometry
		mission._message("No clear pickup yet · move to open ground or water")
		return
	truck=MilitaryTruck.new()
	truck.name="RecoveryTruck"
	truck.set_meta("recovery",true)
	mission.world.add_child(truck)
	truck.global_transform=pose
	mission.world.trucks.append(truck)
	pickup=pose.origin
	arrival_goal=pickup
	state="READY"
	# A short real collision-driven approach where both endpoints are supported.
	if pontoon==null:
		var behind:=_dry_pose(pickup+pose.basis.z*6)
		if behind.origin.is_finite() and absf(behind.origin.y-pickup.y)<.15:
			truck.global_position=behind.origin
			truck.global_basis=pose.basis
			truck.set_physics_process(false)
			state="ARRIVING"
func _sea_pickup(origin: Vector3) -> Vector3:
	var space:=mission.world.get_world_3d().direct_space_state
	for step in 16:
		var point:=origin+Vector3(cos(step*TAU/16),0,sin(step*TAU/16))*15
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x,1000,point.z),Vector3(point.x,-50,point.z),1))
		if hit.is_empty() or not hit.collider.is_in_group("aircraft_water"):continue
		point.y=hit.position.y
		var shape:=BoxShape3D.new()
		shape.size=Vector3(7,4,10)
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=shape;query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*2.2);query.collision_mask=31
		if space.intersect_shape(query).is_empty():return point
	return Vector3.INF
func _create_pontoon(point: Vector3) -> void:
	pontoon=StaticBody3D.new()
	pontoon.name="SeaRescuePontoon"
	mission.world.add_child(pontoon)
	pontoon.global_position=point+Vector3.UP*.2
	MeshKit.box(pontoon,Vector3(6,.4,9),Vector3.ZERO,MeshKit.material(Color("666354")))
	for x in [-2.6,2.6]:MeshKit.box(pontoon,Vector3(.55,.8,9),Vector3(x,-.25,0),MeshKit.material(Color("424c4b")))
	var collision:=CollisionShape3D.new()
	var box:=BoxShape3D.new();box.size=Vector3(6,.4,9);collision.shape=box;pontoon.add_child(collision)
func enter(requested_truck: MilitaryTruck) -> bool:
	if state!="READY" or requested_truck!=truck or not mission.survival.alive() or mission.occupied!=null or mission.interaction.is_operating():return false
	if mission.pilot.global_position.distance_to(truck.global_position+Vector3.UP)>mission.interaction.truck_enter_range:return false
	return_point=mission.safe_base_point(destination)
	if not return_point.is_finite():
		mission._message("Base exit obstructed · clear a hangar approach and try again")
		return false
	state="RETURNING"
	clock=0
	mission.pilot.set_active(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	fade.mouse_filter=Control.MOUSE_FILTER_STOP
	return true
func _return_home() -> void:
	# Recheck against the still-running battle before committing the arrival.
	var point:=mission.safe_base_point(destination)
	if not point.is_finite():
		state="READY";fade.color.a=0;fade.mouse_filter=Control.MOUSE_FILTER_IGNORE
		mission.pilot.set_active(true)
		return
	_clear_pickup()
	mission.pilot.global_position=point
	mission.pilot.velocity=Vector3.ZERO
	mission.pilot.set_active(true)
	mission.pilot.camera.make_current()
	mission.chart_panel.hide()
	get_viewport().gui_release_focus()
	state="FADING_IN"
	clock=0
	returns+=1
	mission._message("Returned to base · pilot health and the running mission preserved" if mission.serviceable_count(destination)>0 else "Returned to base · no usable aircraft at this field; pilot is alive · M for travel")
func cancel_pending() -> void:
	# Finding another aircraft or using existing map travel supersedes pickup.
	# Clear the temporary vehicle so a later loss can request help again.
	if state not in ["REQUESTED","ARRIVING","READY"]:return
	_clear_pickup()
	state="IDLE"
	clock=0

func _clear_pickup() -> void:
	if is_instance_valid(truck):
		mission.world.trucks.erase(truck)
		truck.queue_free()
	truck=null
	if is_instance_valid(pontoon):pontoon.queue_free()
	pontoon=null
func _exit_tree() -> void:
	_clear_pickup()
