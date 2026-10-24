class_name StElmoBattery
extends Node3D
## Explicit player aim/fire relay; never searches for or selects targets.
@export var alignment_degrees: float=2
@export var staggering_seconds: float=.07
@export var aim_distance: float=1500
@export var firing_volume_db: float=-16
var reference_camera: Camera3D
var guns: Array[BritishAAGun]=[]
var lead: StElmoBofors
var orders: Dictionary={}
var aim_point: Vector3
var world: MaltaWorld
var commanding: bool=false
var clock: float=0
var fire_since: float=-1
func _ready() -> void:
	name="StElmoBoforsBattery"
	var layout:=StElmoLocations.data()
	if layout.has("reference_camera"):
		var view: Dictionary=layout.reference_camera
		reference_camera=Camera3D.new()
		reference_camera.name="FortStElmoReferenceCamera"
		reference_camera.fov=float(view.fov)
		reference_camera.near=.5 # Preserve wall/deck depth precision at aerial distances.
		reference_camera.far=12000
		add_child(reference_camera)
		reference_camera.global_position=MaltaGeography.vector(view.position)
		reference_camera.look_at(MaltaGeography.vector(view.target))
		reference_camera.current=false # Debug/Remote inspector only; never steals play.

	for i in range(3):
		var gun:=StElmoBofors.new()
		gun.name="StElmo_Bofors_%d"%(i+1)
		gun.fort=self
		gun.battery=world.aa_battery
		gun.weapon=world.aa_battery.light_definition.duplicate()
		gun.weapon.sound_volume_db=firing_volume_db
		add_child(gun)
		var point: Array=layout.gun_positions[i]
		gun.global_position=Vector3(point[0],point[2]+.025,point[1])
		guns.append(gun)
	call_deferred("_place_predictor")

func _place_predictor() -> void:
	# Imported city collision enters the physics broad phase on the following
	# ticks; querying in the first deferred idle can see only underlying terrain.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():return
	# Search real supported deck around the established fort spawn.
	var start: Vector3=StElmoLocations.position_for("st_elmo")-Vector3.UP*1.05
	var offsets: Array[Vector3]=[]
	for x in range(-28,29,4):
		for z in range(-28,29,4):
			var offset:=Vector3(x,0,z)
			if offset.length()>=6:offsets.append(offset)
	offsets.sort_custom(func(a,b):return a.length_squared()<b.length_squared())
	for offset in offsets:
		var p: Vector3=start+offset
		# Start above every fort roof, never inside a building/deck collider.
		var ray:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*2000,p+Vector3.DOWN*8,1)
		var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y<.9 or absf(hit.position.y-start.y)>.35:continue
		var supported:=true
		for corner in [Vector3(-2.3,0,-2.4),Vector3(2.3,0,-2.4),Vector3(-2.3,0,2.4),Vector3(2.3,0,2.4),Vector3(0,0,3.5)]:
			var probe:=PhysicsRayQueryParameters3D.create(p+corner+Vector3.UP*2000,p+corner+Vector3.DOWN*8,1)
			var floor:=get_world_3d().direct_space_state.intersect_ray(probe)
			if floor.is_empty() or floor.normal.y<.9 or absf(floor.position.y-hit.position.y)>.2:supported=false;break
		if not supported:continue
		var shape:=BoxShape3D.new();shape.size=Vector3(5,2.4,5.5)
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape
		query.transform=Transform3D(Basis.IDENTITY,hit.position+Vector3.UP*1.3);query.collision_mask=31
		if not get_world_3d().direct_space_state.intersect_shape(query).is_empty():continue
		var walker:=CapsuleShape3D.new();walker.radius=.4;walker.height=1.8
		var route:=PhysicsShapeQueryParameters3D.new();route.shape=walker
		route.transform=Transform3D(Basis.IDENTITY,start+Vector3.UP)
		route.motion=hit.position+Vector3.BACK*3.5-start;route.collision_mask=1
		var travel:=get_world_3d().direct_space_state.cast_motion(route)
		if travel[0]<.99:continue
		world.aa_battery.add_bofors_post("st_elmo",guns,Transform3D(Basis.IDENTITY,hit.position+Vector3.UP*.025))
		return
	push_warning("No clear supported St Elmo predictor platform found")
func toggle(gun: StElmoBofors) -> void:
	if commanding:cancel();return
	if not gun.mounted or gun.is_destroyed:return
	lead=gun
	commanding=true
	for other in guns:
		if other!=lead:other.command_station=self
func command_active() -> bool:
	return commanding and is_instance_valid(lead) and lead.mounted and not lead.is_destroyed and not lead.mouse_controls.blocked()
func operational_count() -> int:
	var count:int=0
	for gun in guns:
		if not gun.is_destroyed:count+=1
	return count
func cancel() -> void:
	commanding=false
	orders.clear()
	fire_since=-1
	for gun in guns:
		gun.trigger_held=false
		if gun.command_station==self:gun.command_station=null
func _physics_process(delta: float) -> void:
	clock+=delta
	if not commanding:return
	if not command_active():cancel();return
	var start:=lead.muzzle.global_position
	var end:=start-lead.muzzle.global_basis.z*aim_distance
	var query:=PhysicsRayQueryParameters3D.create(start,end,15,[lead.get_rid()])
	query.collide_with_areas=true
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	aim_point=hit.position if not hit.is_empty() else end
	var firing: bool=lead.trigger_held and not lead.crew.transitioning
	if not firing:orders.clear();fire_since=-1;return
	if fire_since<0:fire_since=clock
	for i in range(guns.size()):
		var gun: BritishAAGun=guns[i]
		if gun!=lead and not gun.is_destroyed and clock-fire_since>=staggering_seconds*i:orders[gun]=true
func drive_gun(gun: BritishAAGun,delta: float) -> void:
	if not command_active() or gun.is_destroyed or gun.mounted or gun.crew.health.hp<=0:return
	var local:=gun.to_local(aim_point)-gun.to_local(gun.yaw.global_position)
	var desired_yaw:=atan2(-local.x,-local.z)
	var desired_pitch:=atan2(local.y,Vector2(local.x,local.z).length())
	var allowed: bool=desired_pitch>=deg_to_rad(gun.minimum_elevation_degrees) and desired_pitch<=deg_to_rad(gun.maximum_elevation_degrees)
	gun.yaw.rotation.y=rotate_toward(gun.yaw.rotation.y,desired_yaw,deg_to_rad(gun.traverse_degrees)*delta)
	gun.elevation.rotation.x=move_toward(gun.elevation.rotation.x,clampf(desired_pitch,deg_to_rad(gun.minimum_elevation_degrees),deg_to_rad(gun.maximum_elevation_degrees)),deg_to_rad(gun.elevation_degrees)*delta)
	var direction: Vector3=(aim_point-gun.muzzle.global_position).normalized()
	if not allowed or not orders.has(gun) or rad_to_deg((-gun.muzzle.global_basis.z).angle_to(direction))>alignment_degrees:return
	var query:=PhysicsRayQueryParameters3D.create(gun.muzzle.global_position,aim_point-direction*2,31,[gun.get_rid()])
	query.collide_with_areas=true
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and (not hit.collider.has_method("get_team_id") or hit.collider.get_team_id()!=CombatTeams.ENEMY):return
	gun.fire_round(true)
