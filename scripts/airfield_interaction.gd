class_name AirfieldInteraction
extends Node
## Exclusive ground controller routing; never resets the running world or battle.
@export var gun_mount_range: float = 6
@export var truck_enter_range: float = 4.5
var mission: MaltaMission
var occupied_gun: BritishAAGun
var occupied_vehicle: MilitaryTruck
var sight: AAAimReticle
var previous_mouse_mode: int = Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	mission.world.aa_battery.bofors_post_added.connect(_connect_predictor)
	sight = AAAimReticle.new()
	mission.canvas.add_child(sight)
	sight.visible = false
	for gun in mission.world.aa_battery.guns + mission.world.fort_battery.guns + mission.world.aa_battery.command_stations + mission.world.aa_battery.bofors_posts:
		gun.destroyed.connect(_gun_destroyed.bind(gun))
	# AA placement is deferred until the world is ready.
	call_deferred("_connect_guns")

func _connect_predictor(post: BritishAAGun) -> void:
	if not post.destroyed.is_connected(_gun_destroyed.bind(post)):
		post.destroyed.connect(_gun_destroyed.bind(post))

func _connect_guns() -> void:
	for gun in mission.world.aa_battery.guns + mission.world.fort_battery.guns + mission.world.aa_battery.command_stations + mission.world.aa_battery.bofors_posts:
		if not gun.destroyed.is_connected(_gun_destroyed.bind(gun)):
			gun.destroyed.connect(_gun_destroyed.bind(gun))

func is_operating() -> bool:
	return is_instance_valid(occupied_gun) or is_instance_valid(occupied_vehicle)

func nearest() -> Node3D:
	if is_operating() or mission.occupied != null or not mission.pilot.active or mission.pilot.health.hp<=0: return null
	var best: Node3D = mission.nearest_serviceable()
	var distance := mission.pilot.global_position.distance_to(best.global_position) if best != null else INF
	for gun in mission.world.aa_battery.guns + mission.world.fort_battery.guns:
		var d := mission.pilot.global_position.distance_to(gun.global_position + Vector3.UP)
		if not gun.is_destroyed and d < gun_mount_range and d < distance:
			best = gun
			distance = d
	for truck in mission.world.trucks:
		var d := mission.pilot.global_position.distance_to(truck.global_position + Vector3.UP)
		if truck.get_meta("recovery",false) and mission.recovery.state!="READY":continue
		if not truck.occupied and absf(truck.speed) < mission.maximum_exit_speed and d < truck_enter_range and d < distance:
			best = truck
			distance = d
	return best

func nearest_command() -> BritishAAGun:
	if is_operating() or mission.occupied!=null or not mission.pilot.active:return null
	var best: BritishAAGun=null
	var distance:=4.5
	for station in mission.world.aa_battery.command_stations + mission.world.aa_battery.bofors_posts:
		var d: float=mission.pilot.global_position.distance_to(station.global_position)
		if not station.is_destroyed and d<distance:best=station;distance=d
	return best

func interact() -> bool:
	if is_instance_valid(occupied_gun): return leave_gun()
	if is_instance_valid(occupied_vehicle): return leave_vehicle()
	var object := nearest()
	if object is BritishAAGun: return mount_gun(object)
	if object is MilitaryTruck: return enter_vehicle(object)
	if object is FlightAircraft: return mission.board_aircraft(object)
	mission._message("Approach an AA gun, truck or stopped aircraft · E to enter")
	return false

func _hide_pilot() -> void:
	previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mission.pilot.set_active(false)
	if is_instance_valid(mission.session.hud):
		mission.session.hud.hide()
		mission.session.hud.flight_input_enabled = false
	mission.session.encounters.set_target(null)

func mount_gun(gun: BritishAAGun) -> bool:
	if is_operating() or mission.occupied != null or not mission.pilot.active or (gun != nearest_command() if gun is AACommandStation else gun != nearest()) or gun.is_destroyed or mission_ended(): return false
	if gun is StElmoBofors and gun.crew.transitioning:return false
	occupied_gun = gun
	_hide_pilot()
	gun.start_operation(self)
	if not gun.mounted:
		occupied_gun=null
		_restore_pilot(mission.pilot.global_position)
		return false
	if mission.pilot.combat_enabled:
		# Hidden seated visual, live collision capsule at the actual operator.
		mission.pilot.global_position=gun.to_global(Vector3(0,1.45,1.55))
	sight.visible = true
	sight.gun=gun
	mission._message("Bofors observation · LMB acquire · TAB visible targets · G gun scope · ENTER assign · F exit" if gun is BoforsCommandPost else ("Battery command · RMB designates target / area · LMB orders a salvo · F exits" if gun is AACommandStation else "Mouse aims · LMB fire · RMB zoom · ESC releases cursor; click to recapture"))
	return true

func enter_vehicle(truck: MilitaryTruck) -> bool:
	if truck.get_meta("recovery",false):return mission.recovery.enter(truck)
	if is_operating() or mission.occupied != null or not mission.pilot.active or truck != nearest(): return false
	occupied_vehicle = truck
	_hide_pilot()
	if mission.pilot.combat_enabled:truck.add_collision_exception_with(mission.pilot)
	truck.start_driving()
	mission._message("W forward · S reverse · A/D steer · SPACE brake · E exit when stopped")
	return true

func find_exit(body: Node3D, radius: float) -> Vector3:
	var space := body.get_world_3d().direct_space_state
	for extra in [0,2,4]:
		for side in [Vector3.RIGHT,Vector3.LEFT,Vector3.BACK,Vector3.FORWARD,Vector3(1,0,1).normalized(),Vector3(-1,0,1).normalized()]:
			var point: Vector3 = body.global_position + body.global_basis * side * (radius+extra)
			var floor_query := PhysicsRayQueryParameters3D.create(point + Vector3.UP*4,point + Vector3.DOWN*8,1,[body.get_rid()])
			var hit := space.intersect_ray(floor_query)
			if hit.is_empty() or hit.normal.y < 0.65: continue
			var position: Vector3 = hit.position + Vector3.UP * 1.05
			var shape := CapsuleShape3D.new()
			shape.radius = .4
			shape.height = 1.9
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform = Transform3D(Basis.IDENTITY,position)
			query.collision_mask = 31
			query.exclude = [mission.pilot.get_rid()]
			if space.intersect_shape(query).is_empty(): return position
	return Vector3.INF

func _restore_pilot(position: Vector3) -> void:
	mission.pilot.global_position = position
	mission.pilot.velocity = Vector3.ZERO
	mission.pilot.set_active(mission.pilot.health.hp>0)
	mission.pilot.camera.make_current()
	Input.mouse_mode = previous_mouse_mode
	sight.visible = false
	sight.gun=null

func leave_gun(force: bool = false) -> bool:
	if not is_instance_valid(occupied_gun): return false
	var position := find_exit(occupied_gun,5)
	if position == Vector3.INF:
		if not force:
			mission._message("No clear ground beside the gun")
			return false
		position = mission.world.fields[mission.home].pilot_spawn
	occupied_gun.stop_operation()
	occupied_gun = null
	_restore_pilot(position)
	return true

func leave_vehicle() -> bool:
	if not is_instance_valid(occupied_vehicle): return false
	if absf(occupied_vehicle.speed) > mission.maximum_exit_speed or not occupied_vehicle.grounded:
		mission._message("Brake to a stop on the ground before exiting the truck")
		return false
	var position := find_exit(occupied_vehicle,2.4)
	if position == Vector3.INF:
		mission._message("No clear exit beside the truck")
		return false
	occupied_vehicle.stop_driving()
	occupied_vehicle.remove_collision_exception_with(mission.pilot)
	occupied_vehicle = null
	_restore_pilot(position)
	return true

func _gun_destroyed(gun: BritishAAGun) -> void:
	if occupied_gun == gun:
		leave_gun(true)
		mission._message("Command post destroyed · surviving guns remain available individually" if gun is AACommandStation else ("AA gun destroyed · reach the other operational gun" if mission.session.game_mode=="aa_defence" else "AA gun destroyed · aircraft remain available"))

func mission_ended() -> bool:
	if is_instance_valid(mission.session.aa_defence):return mission.session.aa_defence.is_finished()
	return mission.session.encounters.ended or mission.session.encounters.complete or (is_instance_valid(mission.session.interception) and mission.session.interception.phase in ["SUCCESS","FAILED"])

func _process(_delta: float) -> void:
	if mission.pilot.combat_enabled and occupied_vehicle!=null:
		mission.pilot.global_position=occupied_vehicle.to_global(Vector3(.3,1.8,-.5))
	if mission.pilot.combat_enabled and occupied_gun!=null:
		mission.pilot.global_position=occupied_gun.to_global(Vector3(0,1.45,1.55))
	if occupied_gun != null and mission_ended(): leave_gun(true)

func prompt() -> String:
	if occupied_gun is AACommandStation:
		return occupied_gun.status_text()+"\nESC Pause / sensitivity · M Map · R Restart"
	if occupied_gun != null:
		return occupied_gun.status_text() + "\nMOUSE Aim · LMB Fire · RMB Zoom · arrows alternative · SPACE Fine aim · E Exit AA Gun · M Map · ESC Pause · R Restart"
	if occupied_vehicle != null:
		return "MILITARY TRUCK · %d km/h\nW Forward · S Reverse · A/D Steer · SPACE Brake\nE Exit when stopped · M Map · ESC Pause · R Full restart" % roundi(absf(occupied_vehicle.speed)*3.6)
	if nearest_command()!=null:return "F Operate Bofors Predictor · observe and assign targets" if nearest_command() is BoforsCommandPost else "F Enter Heavy AA Battery Command · mouse target designation"
	var object := nearest()
	if object is BritishAAGun: return "E Mount AA Gun"
	if object is MilitaryTruck: return "E Enter recovery truck · return to departure airfield" if object.get_meta("recovery",false) else "E Enter Military Truck"
	if object is FlightAircraft: return "E Board " + object.display_name
	return "Approach a truck, AA gun or aircraft · E to enter"

func _exit_tree() -> void:
	if is_instance_valid(occupied_gun): occupied_gun.stop_operation()
	if is_instance_valid(occupied_vehicle): occupied_vehicle.stop_driving()
	Input.mouse_mode = previous_mouse_mode
