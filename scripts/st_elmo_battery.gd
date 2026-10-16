class_name StElmoBattery
extends Node3D
## Explicit player aim/fire relay; never searches for or selects targets.
@export var alignment_degrees: float=2
@export var staggering_seconds: float=.07
@export var aim_distance: float=1500
@export var firing_volume_db: float=-16
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
