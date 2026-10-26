class_name BoforsCommandPost
extends AACommandStation
## Player-directed light battery: manual sight laying or optional measured lead.
## Only a held player trigger permits connected guns to discharge.
@export var manual_sight_range: float = 1500
@export var battery_aim_assist: bool = false
@export var observation_range: float = 4000
@export var observation_interval: float = .12
@export var lost_after_seconds: float = 1.25
@export var settling_seconds: float = 2.0
@export var measurement_error_metres: float = .5
@export var call_recordings: Dictionary[String, AudioStream] = {}
var assigned_guns: Array[BritishAAGun] = []
var detected: Array[FlightAircraft] = []
var gun_scope: int = 0 # zero: whole battery; otherwise gun index + 1
var observed_position: Vector3
var observed_velocity: Vector3
var previous_measurement: Vector3
var last_seen: float = -100
var track_seconds: float = 0
var quality: float = 0
var ready_announced: bool = false
var radio_sequence: int = 0
var shot_call_clock: float = -100
var report: String = "No observed target"
var crew: StElmoCrew
var radio: MissionRadioQueue
var mission_context: MaltaMission

func _ready() -> void:
	super._ready()
	add_to_group("bofors_predictor_posts")
	command_label.text = "F · BOFORS COMMAND\nPlayer-controlled battery"
	command_label.pixel_size=.009
	command_label.position.y=3.1
	_decorate()
	radio = MissionRadioQueue.new()
	radio.definition = HarbourDefinition.new()
	add_child(radio)
	# Keep observer subtitles below the existing mission commander channel.
	radio.caption.position.y=650
	crew = BoforsObserverCrew.new()
	crew.gun = self
	add_child(crew)
	for gun in battery_guns: gun.predictor_post = self

func _decorate() -> void:
	var stone := MeshKit.material(Color("9a9277"))
	var steel := MeshKit.material(Color("495044"))
	var wood := MeshKit.material(Color("6e644f"))
	var glass := MeshKit.material(Color("1a3037"),.25)
	# Sandbag flanks and a rear entrance, clear of the live operator capsule.
	for side in [-1,1]:
		for row in 3:
			for i in 7:
				var bag := MeshKit.sphere(self,Vector3(.72,.32,.75),Vector3(side*2.05,.16+row*.28,-1.6+i*.55),stone)
				bag.rotation.y = .05 * (i%3-1)
		var flank := CollisionShape3D.new()
		var shape := BoxShape3D.new();shape.size=Vector3(.65,.9,4.1)
		flank.shape=shape;flank.position=Vector3(side*2.05,.45,.1);add_child(flank)
		for i in 2:MeshKit.box(self,Vector3(.65,.55,.5),Vector3(side*(1.25+i*.55),.28,2.4),stone)
	# Original Kerrison-inspired mechanical cabinet, rangefinder and phone.
	MeshKit.box(self,Vector3(.9,.65,.6),Vector3(-.5,1.25,.2),steel)
	for i in 3:
		MeshKit.cylinder(self,.09,.025,Vector3(-.8+i*.25,1.6,.17),glass)
	MeshKit.rod(self,Vector3(-.8,1.95,-.6),Vector3(.8,1.95,-.6),.085,steel)
	for x in [-.82,.82]:MeshKit.sphere(self,Vector3(.1,.1,.1),Vector3(x,1.95,-.6),glass)
	MeshKit.rod(self,Vector3(0,1,-.6),Vector3(0,1.95,-.6),.055,steel)
	MeshKit.box(self,Vector3(.42,.16,.28),Vector3(.6,1.17,.35),wood)
	MeshKit.rod(self,Vector3(.43,1.34,.35),Vector3(.77,1.34,.35),.06,steel)
	for i in 12:
		var a:=Vector3(.75+i*.07,1.1-i*.085,.6+sin(i*.7)*.06)
		var b:=Vector3(.75+(i+1)*.07,1.1-(i+1)*.085,.6+sin((i+1)*.7)*.06)
		MeshKit.rod(self,a,b,.015,steel)
	MeshKit.box(self,Vector3(.6,.4,.5),Vector3(-1.2,.2,1.1),wood)
	var equipment:=CollisionShape3D.new()
	var box:=BoxShape3D.new();box.size=Vector3(2.3,1.3,1.4)
	equipment.shape=box;equipment.position=Vector3(0,1.5,-.3);add_child(equipment)

func start_operation(operator: AirfieldInteraction=null) -> void:
	if is_destroyed: return
	# Keep Bofors continuous trigger handling separate from heavy single salvos.
	mounted=true;operator_session=operator
	command_label.hide()
	for gun in battery.guns+battery_guns:
		var label:=gun.get_node_or_null("FriendlyAALabel")
		if label!=null:label.hide()
	if operator!=null:
		mission_context=operator.mission
		var safe:=operator.find_exit(self,5)
		if safe!=Vector3.INF and crew.health.hp>0:crew.move_to_wait(safe-Vector3.UP*1.05)
	camera.make_current();mouse_controls.begin();mouse_controls.release_fire=true
	trigger_held=false
	for gun in battery_guns:
		if not gun.is_destroyed and not gun.mounted:gun.command_station=self

func stop_operation() -> void:
	super.stop_operation()
	command_label.show()
	for gun in battery_guns:
		if is_instance_valid(gun):
			var label:=gun.get_node_or_null("FriendlyAALabel")
			if label!=null:label.show()
	if is_instance_valid(crew) and not is_destroyed:crew.return_to_seat()

func toggle_battery_assist() -> void:
	battery_aim_assist=not battery_aim_assist
	cancel_orders() # Switching modes must not inherit a held trigger.

func selected(gun: BritishAAGun) -> bool:
	var index: int=battery_guns.find(gun)
	return index>=0 and (gun_scope==0 or gun_scope==index+1) and not gun.is_destroyed and not gun.mounted

func command_solution(gun: BritishAAGun) -> Dictionary:
	if battery_aim_assist:
		var solution: Dictionary=get_solution(gun)
		return solution if solution.get("valid",false) else {}
	# Manual mode follows the player's actual sight, with parallax convergence.
	# It has no target selection, velocity lead or gravity compensation.
	var origin: Vector3=camera.global_position
	var point: Vector3=origin-camera.global_basis.z*manual_sight_range
	var excludes: Array[RID]=[get_rid()]
	if is_instance_valid(mission_context):excludes.append(mission_context.pilot.get_rid())
	var ray:=PhysicsRayQueryParameters3D.create(origin,point,1,excludes)
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():point=hit.position
	var direction: Vector3=(point-gun.muzzle.global_position).normalized()
	var local: Vector3=gun.yaw.get_parent().global_basis.inverse()*direction
	var pitch: float=atan2(local.y,Vector2(local.x,local.z).length())
	return {"direction":direction,"yaw":atan2(-local.x,-local.z),"pitch":pitch,
		"aimable":pitch>=deg_to_rad(gun.minimum_elevation_degrees) and pitch<=deg_to_rad(gun.maximum_elevation_degrees)}

func fire_round(_command_order: bool=false) -> bool:
	if not command_active() or not trigger_held:return false
	var ordered: bool=false
	for gun in battery_guns:
		if selected(gun) and gun.command_station==self:
			orders[gun]={} # Authorization only; every gun still checks its own reload.
			ordered=true
	return ordered

func drive_gun(gun: BritishAAGun,delta: float) -> void:
	if not command_active() or not selected(gun):return
	var solution: Dictionary=command_solution(gun)
	if solution.is_empty() or not solution.get("aimable",false):return
	gun.yaw.rotation.y=rotate_toward(gun.yaw.rotation.y,solution.yaw,deg_to_rad(gun.traverse_degrees)*delta)
	gun.elevation.rotation.x=move_toward(gun.elevation.rotation.x,solution.pitch,deg_to_rad(gun.elevation_degrees)*delta)
	if not trigger_held or not orders.has(gun):return
	if not Input.is_action_pressed("fire") and not (Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("aa_fire")):return
	if (-gun.muzzle.global_basis.z).angle_to(solution.direction)>deg_to_rad(firing_tolerance_degrees):return
	if gun.fire_round(true):commanded_shots+=1

func _input(event: InputEvent) -> void:
	if not mounted or mouse_controls.blocked() or event.is_echo():return
	if event.is_action_pressed("aa_battery_toggle"):
		toggle_battery_assist();get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_TAB or event.keycode==KEY_TAB:
			cycle_target();get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_G or event.keycode==KEY_G:
			gun_scope=(gun_scope+1)%(battery_guns.size()+1);cancel_orders();get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_ENTER or event.keycode==KEY_ENTER:
			assign_target();get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	clock+=delta
	if not mounted:marker.hide()
	if is_destroyed:return
	if not mounted and is_instance_valid(crew) and crew.health.hp<=0:
		lose_target(false);return
	if is_instance_valid(mission_context) and mission_context.interaction.mission_ended():
		lose_target(false);radio.stop();return
	if command_active():
		trigger_held=mouse_controls.sample(delta)
		if trigger_held:fire_round()
		else:orders.clear()
	else:cancel_orders()
	solution_clock-=delta
	if solution_clock>0:return
	solution_clock=observation_interval
	if mounted:scan_visible_targets()
	if not is_instance_valid(target):
		if designated:lose_target()
		return
	if not can_observe(target,mounted):
		marker.hide();solutions.clear();quality=maxf(0,quality-.2)
		if clock-last_seen>=lost_after_seconds:lose_target()
		return
	update_solutions(observation_interval)
	if mounted and not camera.is_position_behind(observed_position):
		marker.position=camera.unproject_position(observed_position)+Vector2(16,0)
		marker.text="OBSERVED · %s\n%s"%[target.display_name,report]
		marker.show()

func scan_visible_targets() -> void:
	detected.clear()
	for aircraft in battery.candidates():
		if can_observe(aircraft,true):detected.append(aircraft)
	detected.sort_custom(func(a,b):return camera.global_position.distance_to(a.global_position)<camera.global_position.distance_to(b.global_position))

func can_observe(aircraft: FlightAircraft,in_sight: bool=false) -> bool:
	if not is_instance_valid(aircraft) or aircraft.team_id!=CombatTeams.ENEMY or aircraft.is_destroyed or aircraft.is_crashed:return false
	var origin: Vector3=camera.global_position if mounted else global_position+Vector3.UP*2
	var offset: Vector3=aircraft.global_position-origin
	if offset.length()>observation_range:return false
	if in_sight and not camera.is_position_in_frustum(aircraft.global_position):return false
	if in_sight and (-camera.global_basis.z).angle_to(offset)>deg_to_rad(camera.fov*.6):return false
	return clear_line(origin,aircraft)

func clear_line(origin: Vector3,aircraft: FlightAircraft,extra: RID=RID()) -> bool:
	var exclude: Array[RID]=[]
	if extra.is_valid():exclude.append(extra) # Gun sight: the post/observer can obstruct it.
	else:
		exclude.append(get_rid())
		if is_instance_valid(crew):exclude.append(crew.get_rid())
	if is_instance_valid(mission_context):exclude.append(mission_context.pilot.get_rid())
	var ray:=PhysicsRayQueryParameters3D.create(origin,aircraft.global_position,31,exclude)
	ray.collide_with_areas=true
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.collider==aircraft or (hit.collider is AircraftHitbox and hit.collider.damage_system.aircraft==aircraft)

func designate_from_sight() -> void:
	scan_visible_targets()
	var best: FlightAircraft
	var angle: float=deg_to_rad(6)
	for aircraft in detected:
		var error: float=(-camera.global_basis.z).angle_to(aircraft.global_position-camera.global_position)
		if error<angle:angle=error;best=aircraft
	if best!=null:designate(best)

func cycle_target() -> void:
	scan_visible_targets()
	if detected.is_empty():return
	designate(detected[(detected.find(target)+1)%detected.size()])

func designate(aircraft: FlightAircraft) -> void:
	if not mounted or not can_observe(aircraft,true):return
	target=aircraft;designated=true
	assigned_guns.clear();solutions.clear()
	observed_position=aircraft.global_position
	previous_measurement=observed_position;observed_velocity=Vector3.ZERO
	last_seen=clock;track_seconds=0;quality=0;acceleration=0;ready_announced=false
	report="Tracking acquisition — keep the aircraft in view"
	message("acquired","Target acquired!")
	var offset: Vector3=observed_position-global_position
	var bearing: int=roundi(fposmod(rad_to_deg(atan2(offset.x,-offset.z)),360))%360
	var digits: Array[String]=[]
	var words: Array[String]=["zero","one","two","three","four","five","six","seven","eight","nine"]
	for digit in "%03d"%bearing:digits.append(words[int(digit)])
	message("bearing","Enemy aircraft bearing %s!"%"-".join(digits),"bearing_%03d"%bearing)
	var yards: int=roundi(offset.length()*1.09361/50)*50
	message("range","Range %d yards!"%yards,"range_%d"%yards)

func assign_target() -> void:
	if not mounted or not is_instance_valid(target) or not can_observe(target,true):return
	assigned_guns.clear()
	for i in battery_guns.size():
		if (gun_scope==0 or gun_scope==i+1) and not battery_guns[i].is_destroyed:assigned_guns.append(battery_guns[i])
	message("assigned","Target assigned to %s. Gunner, follow the predictor."%("battery" if gun_scope==0 else "gun %d"%gun_scope))

func update_solutions(delta: float) -> void:
	if not is_instance_valid(target) or not can_observe(target,mounted):solutions.clear();return
	noise_clock-=delta
	if noise_clock<=0:
		noise_clock=.8
		position_error=Vector3(rng.randfn(0,1),rng.randfn(0,1),rng.randfn(0,1))*measurement_error_metres
	var measurement: Vector3=target.global_position+position_error
	var elapsed: float=maxf(clock-last_seen,delta)
	var measured: Vector3=(measurement-previous_measurement)/elapsed
	var previous: Vector3=observed_velocity
	observed_velocity=observed_velocity.lerp(measured,1-exp(-3*elapsed))
	acceleration=lerpf(acceleration,(observed_velocity-previous).length()/elapsed,.3)
	track_seconds+=elapsed
	quality=clampf(track_seconds/maxf(settling_seconds,.1),0,1)/(1+maxf(acceleration-4,0)*.06)
	observed_position=measurement;previous_measurement=measurement;last_seen=clock
	var heading: float=fposmod(rad_to_deg(atan2(observed_velocity.x,-observed_velocity.z)),360)
	report="EST RANGE %d m / %d yd · ALT %d m AMSL · HDG %03d° · TRACK %d%%"%[roundi(global_position.distance_to(measurement)),roundi(global_position.distance_to(measurement)*1.09361),roundi(measurement.y),roundi(heading),roundi(quality*100)]
	solutions.clear()
	for gun in battery_guns:
		if not is_instance_valid(gun) or gun.is_destroyed:continue
		var origin: Vector3=gun.muzzle.global_position
		var result:=AAFireControl.solve(origin,observed_position,observed_velocity,gun.projectile_speed,battery.pool_for(gun.weapon).gravity,gun.maximum_lifetime)
		if result.is_empty():continue
		var local: Vector3=gun.yaw.get_parent().global_basis.inverse()*result.direction
		result.yaw=atan2(-local.x,-local.z)
		result.pitch=atan2(local.y,Vector2(local.x,local.z).length())
		result.aimable=result.pitch>=deg_to_rad(gun.minimum_elevation_degrees) and result.pitch<=deg_to_rad(gun.maximum_elevation_degrees)
		result.valid=result.valid and result.aimable and origin.distance_to(observed_position)<=gun.range_metres and clear_line(origin,target,gun.get_rid())
		result.quality=quality
		result.range_metres=origin.distance_to(observed_position)
		result.aim_point=origin+result.direction*gun.projectile_speed*result.time
		solutions[gun]=result
	var feasible: bool=solutions.values().any(func(s):return s.valid)
	if quality>.65 and feasible and not ready_announced:
		ready_announced=true;message("ready","Predictor ready!")
	if quality<.35 or not feasible:ready_announced=false

func get_solution(gun: BritishAAGun) -> Dictionary:
	if is_destroyed or not assigned_guns.has(gun) or not is_instance_valid(target) or target.is_destroyed or target.is_crashed or clock-last_seen>observation_interval*2:return {}
	return solutions.get(gun,{})

func lose_target(announce: bool=true) -> void:
	if announce and is_instance_valid(target):message("lost","Target lost!")
	target=null;designated=false;quality=0
	marker.hide()
	assigned_guns.clear();solutions.clear();detected.clear()

func message(id: String,text: String,recording_key: String="") -> void:
	radio_sequence+=1
	radio.cue("%s_%d"%[id,radio_sequence],text,call_recordings.get(id if recording_key.is_empty() else recording_key),false,id in ["acquired","lost"])
	if not radio.pending.is_empty():radio.pending.back().speaker="BATTERY OBSERVER"
	# Target reports must not queue several minutes of stale instructions.
	while radio.pending.size()>4:radio.pending.pop_front()

func notify_shot() -> void:
	if clock-shot_call_clock>8:
		shot_call_clock=clock;message("fire","Open fire!")

func take_damage(amount: float) -> void:
	super.take_damage(amount)
	if is_destroyed:
		lose_target(false)
		if is_instance_valid(crew):crew.fallen()

func status_text() -> String:
	var operational: int=battery_guns.filter(func(g):return not g.is_destroyed).size()
	var ready: int=battery_guns.filter(func(g):return selected(g) and g.cooldown<=0).size()
	var mode: String="ASSIST ON" if battery_aim_assist else "MANUAL"
	var solution: String=""
	if battery_aim_assist:
		if not is_instance_valid(target):solution=" · Tab select target"
		elif assigned_guns.is_empty():solution=" · Enter assign"
		elif not battery_guns.any(func(g):return selected(g) and not command_solution(g).is_empty()):solution=" · OUTSIDE FIRING ENVELOPE"
		else:solution=" · lead ready" if quality>.65 else " · tracking settling"
	return "BOFORS COMMAND · %s%s\n%s\n%s · %d operational · %d ready"%[mode,solution,report,"BATTERY" if gun_scope==0 else "GUN %d"%gun_scope,operational,ready]
