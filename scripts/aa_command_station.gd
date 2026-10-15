class_name AACommandStation
extends BritishAAGun
## A staffed predictor post. Only an explicit player salvo creates firing orders.
@export var solution_refresh_seconds: float=.1
@export var stagger_seconds: float=.3
@export var order_lifetime: float=6
@export var prediction_error_metres: float=8
@export var velocity_error_mps: float=2
@export var manoeuvre_uncertainty: float=.35
@export var gun_difference_metres: float=4
@export var tracking_delay: float=.15
@export var firing_tolerance_degrees: float=.35
var field_id: String
var battery_guns: Array[BritishAAGun]=[]
var target: FlightAircraft
var designated: bool=false
var designated_point: Vector3
var predicted_point: Vector3
var solutions: Dictionary={}
var orders: Dictionary={}
var clock: float=0
var solution_clock: float=0
var noise_clock: float=0
var position_error: Vector3
var velocity_error: Vector3
var last_velocity: Vector3
var acceleration: float=0
var command_label: Label3D
var marker: Label
var salvos_issued: int=0
var commanded_shots: int=0

func _ready() -> void:
	weapon=AAWeaponDefinition.new()
	weapon.mouse_response=24
	traverse_degrees=140
	elevation_degrees=100
	minimum_elevation_degrees=-30
	maximum_elevation_degrees=85
	hp=max_hp
	collision_layer=1
	collision_mask=0
	add_to_group("friendly_aa_commands")
	rng.randomize()
	var metal:=MeshKit.material(Color("445044"))
	var wood:=MeshKit.material(Color("716451"))
	MeshKit.box(self,Vector3(1.8,.15,1.2),Vector3(0,1,0),wood)
	for x in [-.65,.65]:MeshKit.rod(self,Vector3(x,0,.4),Vector3(x,.95,.4),.06,metal)
	yaw=Node3D.new()
	yaw.position.y=1.65
	add_child(yaw)
	elevation=Node3D.new()
	yaw.add_child(elevation)
	elevation_origin=Vector3.ZERO
	MeshKit.box(elevation,Vector3(.7,.28,.6),Vector3.ZERO,metal)
	for x in [-.22,.22]:MeshKit.rod(elevation,Vector3(x,0,.15),Vector3(x,0,-.65),.1,metal)
	muzzle=Node3D.new()
	elevation.add_child(muzzle)
	camera=Camera3D.new()
	camera.fov=58
	camera.far=100000
	camera.position=Vector3(0,.15,-.8)
	muzzle.add_child(camera)
	flash=MeshKit.sphere(self,Vector3.ONE*.01,Vector3.ZERO,metal)
	flash.hide()
	sound=AudioStreamPlayer3D.new()
	add_child(sound)
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(1.8,1.4,1.2)
	collision.shape=shape
	collision.position.y=.7
	add_child(collision)
	var label:=Label3D.new()
	command_label=label
	label.text="F · HEAVY AA BATTERY COMMAND"
	label.position.y=2.8
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size=24
	label.pixel_size=.025
	label.visibility_range_end=400
	add_child(label)
	mouse_controls=AAMouseControls.new()
	mouse_controls.gun=self
	add_child(mouse_controls)
	var canvas:=CanvasLayer.new()
	canvas.layer=9
	add_child(canvas)
	marker=Label.new()
	marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
	marker.modulate=Color("78e6d6")
	marker.add_theme_color_override("font_shadow_color",Color.BLACK)
	marker.add_theme_constant_override("shadow_offset_x",2)
	marker.add_theme_constant_override("shadow_offset_y",2)
	canvas.add_child(marker)
	marker.hide()

func take_damage(amount: float) -> void:
	super.take_damage(amount)
	if is_destroyed:
		command_label.text="COMMAND POST DESTROYED · USE INDIVIDUAL GUNS"
		command_label.modulate=Color("b9a49c")

func start_operation(operator: AirfieldInteraction=null) -> void:
	super.start_operation(operator)
	for nearby in battery.guns:
		var label:=nearby.get_node_or_null("FriendlyAALabel")
		if label!=null:label.hide()
	mouse_controls.release_fire=true # F entering the post is NOT a salvo.
	for gun in battery_guns:
		if not gun.is_destroyed and not gun.mounted:gun.command_station=self

func stop_operation() -> void:
	if mounted:
		for nearby in battery.guns:
			if is_instance_valid(nearby):
				var label:=nearby.get_node_or_null("FriendlyAALabel")
				if label!=null:label.show()
	cancel_orders()
	for gun in battery_guns:
		if is_instance_valid(gun) and gun.command_station==self:gun.command_station=null
	if is_instance_valid(marker):marker.hide()
	super.stop_operation()

func command_active() -> bool:
	return mounted and not is_destroyed and not mouse_controls.blocked()

func cancel_orders() -> void:
	orders.clear()
	trigger_held=true
	if mouse_controls!=null:mouse_controls.release_fire=true

func _physics_process(delta: float) -> void:
	clock+=delta
	marker.visible=false
	if not command_active():
		orders.clear()
		return
	for gun in orders.keys():
		if not is_instance_valid(gun) or gun.is_destroyed or gun.mounted or clock>orders[gun].expiry:orders.erase(gun)
	var pressed: bool=mouse_controls.sample(delta)
	if Input.is_action_just_pressed("aa_zoom") and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:designate_from_sight()
	if target!=null and (not is_instance_valid(target) or target.is_destroyed or target.is_crashed):
		target=null
		designated=false
		orders.clear()
	solution_clock-=delta
	if solution_clock<=0:
		solution_clock=maxf(solution_refresh_seconds,.02)
		update_solutions(solution_clock)
	if pressed and not trigger_held:fire_round()
	trigger_held=pressed
	if designated and camera.current and not camera.is_position_behind(predicted_point):
		marker.position=camera.unproject_position(predicted_point)+Vector2(12,0)
		marker.text="⊕ PREDICTED INTERCEPT"
		marker.visible=true

func designate_from_sight() -> void:
	var forward: Vector3=-camera.global_basis.z
	var best: FlightAircraft=null
	var best_angle: float=deg_to_rad(5)
	for foe in battery.candidates():
		var offset: Vector3=foe.global_position-camera.global_position
		var angle: float=forward.angle_to(offset)
		if angle>=best_angle:continue
		var ray:=PhysicsRayQueryParameters3D.create(camera.global_position,foe.global_position,1,[get_rid()])
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():best=foe;best_angle=angle
	if best!=null:designate(best)
	else:
		var ray:=PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position+forward*3500,1,[get_rid()])
		var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
		designate_area(hit.position if not hit.is_empty() else camera.global_position+forward*3500)

func designate(aircraft: FlightAircraft) -> void:
	if aircraft==null or aircraft.team_id!=CombatTeams.ENEMY or aircraft.is_destroyed:return
	target=aircraft
	last_velocity=aircraft.linear_velocity
	acceleration=0
	designated=true
	orders.clear()
	update_solutions(maxf(solution_refresh_seconds,.02))

func designate_area(point: Vector3) -> void:
	target=null
	designated_point=point
	designated=true
	orders.clear()
	update_solutions(maxf(solution_refresh_seconds,.02))

func update_solutions(delta: float) -> void:
	if not designated:return
	noise_clock-=delta
	var velocity: Vector3=target.linear_velocity if is_instance_valid(target) else Vector3.ZERO
	acceleration=lerpf(acceleration,minf((velocity-last_velocity).length()/maxf(delta,.001),30),.3)
	last_velocity=velocity
	if noise_clock<=0:
		noise_clock=.8
		position_error=Vector3(rng.randfn(0,1),rng.randfn(0,1),rng.randfn(0,1))*prediction_error_metres
		velocity_error=Vector3(rng.randfn(0,1),rng.randfn(0,1),rng.randfn(0,1))*velocity_error_mps
	var point: Vector3=target.global_position if is_instance_valid(target) else designated_point
	point+=position_error+velocity*tracking_delay
	for gun in battery_guns:
		if not is_instance_valid(gun) or gun.is_destroyed:continue
		var jitter: Vector3=orders[gun].jitter if orders.has(gun) else Vector3.ZERO
		var uncertainty: float=acceleration*manoeuvre_uncertainty
		var solution: Dictionary=AAFireControl.solve(gun.muzzle.global_position,point+jitter+velocity_error*uncertainty,velocity+velocity_error,gun.projectile_speed,battery.projectiles.gravity,gun.maximum_lifetime)
		if solution.is_empty():
			solutions.erase(gun)
			continue
		var local: Vector3=gun.global_basis.inverse()*solution.direction
		solution.yaw=atan2(-local.x,-local.z)
		solution.pitch=atan2(local.y,Vector2(local.x,local.z).length())
		solution.aimable=solution.pitch>=deg_to_rad(gun.minimum_elevation_degrees) and solution.pitch<=deg_to_rad(gun.maximum_elevation_degrees)
		solutions[gun]=solution
		predicted_point=solution.point

func fire_round(_command_order: bool=false) -> bool:
	if not command_active() or not designated or not orders.is_empty():return false
	var slot:=0
	for gun in battery_guns:
		if gun.is_destroyed or gun.mounted or gun.cooldown>0 or gun.command_station!=self:continue
		if not solutions.has(gun) or not solutions[gun].aimable:continue
		orders[gun]={"due":clock+slot*maxf(stagger_seconds,0),"expiry":clock+maxf(order_lifetime,1),"jitter":Vector3(rng.randfn(0,1),rng.randfn(0,1),rng.randfn(0,1))*gun_difference_metres}
		slot+=1
	if slot==0:return false
	salvos_issued+=1
	update_solutions(maxf(solution_refresh_seconds,.02))
	return true

func drive_gun(gun: BritishAAGun,delta: float) -> void:
	if not command_active() or not designated or gun.is_destroyed or gun.mounted:return
	if not solutions.has(gun):return
	var solution: Dictionary=solutions[gun]
	if not solution.aimable:
		orders.erase(gun)
		return
	gun.yaw.rotation.y=rotate_toward(gun.yaw.rotation.y,solution.yaw,deg_to_rad(gun.traverse_degrees)*delta)
	gun.elevation.rotation.x=move_toward(gun.elevation.rotation.x,solution.pitch,deg_to_rad(gun.elevation_degrees)*delta)
	if not orders.has(gun):return
	var order: Dictionary=orders[gun]
	if clock>order.expiry:
		orders.erase(gun)
		return
	if clock<order.due:return
	var aligned: bool=(-gun.muzzle.global_basis.z).angle_to(solution.direction)<deg_to_rad(firing_tolerance_degrees)
	if not aligned:return
	gun.fuze_seconds=clampf(solution.time,gun.weapon.minimum_fuze_seconds,gun.maximum_lifetime)
	gun.fuse_distance=gun.fuze_seconds*gun.projectile_speed
	if gun.fire_round(true):
		commanded_shots+=1
		orders.erase(gun)

func status_text() -> String:
	var operational:=0
	var ready:=0
	var valid:=0
	var reloads: String=""
	for gun in battery_guns:
		if not gun.is_destroyed:
			operational+=1
			if gun.cooldown<=0:ready+=1
		if not gun.is_destroyed and solutions.has(gun) and solutions[gun].valid and solutions[gun].aimable:valid+=1
		reloads+=" · G%d %s"%[battery_guns.find(gun)+1,"LOST" if gun.is_destroyed else ("READY" if gun.cooldown<=0 else "%.1fs"%gun.cooldown)]
	var title: String=target.marker_name if is_instance_valid(target) else ("DESIGNATED AREA" if designated else "NO TARGET — RMB designate")
	var distance: float=global_position.distance_to(target.global_position if is_instance_valid(target) else designated_point) if designated else 0
	return "BATTERY COMMAND · POST HP %d/%d · %s · %.0f m\n%d/4 OPERATIONAL · %d READY · %s · %d PENDING · AMMO ∞\n%s\nMOUSE Look · RMB Designate / zoom · LMB Order salvo · F / E Exit"%[hp,max_hp,title,distance,operational,ready,"VALID SOLUTION" if valid>0 else "APPROXIMATE / OUTSIDE ARCS",orders.size(),reloads]
