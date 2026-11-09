class_name TutorialMission
extends Node3D
## A continuous instructional director; never flies, lands or repairs the player.
@export var lessons: TutorialDefinition = preload("res://mission_definitions/tutorial.tres")
# Interface shared with the existing physical DiveAttackPilot for the final lesson.
var definition: DiveDefenceDefinition
var session: Node3D
var phase: String = "BOARD"
var route_index: int = 0
var route: Array[Vector3] = []
var first: FlightAircraft
var second: FlightAircraft
var foe: EnemyAircraft
var guns: Array[BritishAAGun] = []
var centre: Vector3
var effects: Node3D
var siren: InterceptionSiren
var handover_position: Vector3
var landing_position: Vector3
var handover_visuals: Node3D
var landing_outline: Node3D
var parking_outline: Node3D
var handover_taxi_index: int = 0
var marker: Label
var results: PanelContainer
var result_title: Label
var reason: String = ""
var visited: Dictionary = {}
var practised: Dictionary = {}
var settled: float = 0
var damage_applied: bool = false
var damage_count: int = 0
var spawn_count: int = 0
var kills: int = 0
var flap_deployed_seen: bool = false
var gear_retracted_seen: bool = false
var recovery_returns: int = 0
var bombs_released: int = 0
var cancelled: bool = false
var result_transition_queued: bool = false
var emergency_landed: bool = false
var elapsed: float = 0

func _ready() -> void:
	definition=preload("res://mission_definitions/dive_defence.tres").duplicate(true)
	definition.normal_bomb_error=75
	definition.normal_strafe_error_degrees=3
	definition.player_blast_damage=55
	definition.gun_blast_damage=90
	first=session.malta_mission.initial_aircraft
	for plane in session.malta_mission.fleet:
		if plane != first and plane.display_name=="Spitfire Mk I" and session.field.fields[session.home_airfield].contains(plane.global_position):second=plane;break
	for point in lessons.route:route.append(above_terrain(point,200))
	effects=Node3D.new();effects.name="TutorialOrdnance";add_child(effects)
	siren=InterceptionSiren.new();add_child(siren)
	marker=Label.new();marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
	marker.add_theme_font_size_override("font_size",17);marker.add_theme_color_override("font_color",Color("e4bf75"))
	marker.add_theme_color_override("font_shadow_color",Color.BLACK);marker.add_theme_constant_override("shadow_offset_x",1)
	session.malta_mission.canvas.add_child(marker)
	_build_handover_areas()
	_build_results()
	session.malta_mission.pilot.combat_enabled=true
	session.malta_mission.pilot.add_to_group("damageable_ground_pilots")
	recovery_returns=session.malta_mission.recovery.returns
	visited[phase]=true
	call_deferred("_find_guns")

func _build_handover_areas() -> void:
	var field: MaltaAirfield=session.field.fields[session.home_airfield]
	var stand: Vector3=field.to_local(second.global_position)
	handover_position=field.to_global(Vector3(lessons.handover_apron_x,0,stand.z))
	var touchdown_z: float=stand.z-lessons.landing_rollout_lead
	landing_position=field.to_global(Vector3(0,0,touchdown_z))
	handover_visuals=Node3D.new();handover_visuals.name="ReturnAndHandoverAreas";add_child(handover_visuals)
	handover_visuals.global_transform=field.global_transform
	landing_outline=Node3D.new();handover_visuals.add_child(landing_outline)
	var gold:=MeshKit.material(Color("e4bf75"));gold.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var half_width: float=lessons.landing_sector_width*.5
	var half_length: float=lessons.landing_sector_length*.5
	for side in [-1,1]:
		MeshKit.box(landing_outline,Vector3(1.2,.025,lessons.landing_sector_length),Vector3(side*half_width,.25,touchdown_z),gold)
		MeshKit.box(landing_outline,Vector3(lessons.landing_sector_width,.025,1.2),Vector3(0,.25,touchdown_z+side*half_length),gold)
	parking_outline=Node3D.new();handover_visuals.add_child(parking_outline)
	var ring:=TorusMesh.new();ring.inner_radius=maxf(lessons.handover_parking_radius-.25,.1);ring.outer_radius=lessons.handover_parking_radius
	ring.rings=48;ring.ring_segments=6
	var green:=MeshKit.material(Color("8bc49a"));green.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	MeshKit.mesh(parking_outline,ring,green,Vector3(lessons.handover_apron_x,.25,stand.z))
	for visual in handover_visuals.find_children("*","GeometryInstance3D",true,false):visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	handover_visuals.hide() # Visual overlays only: no new ground or obstacles.

func handover_point() -> Vector3:return handover_position

func handover_ready() -> bool:
	if session.malta_mission.return_flow.landed_field(first)!=session.home_airfield:return false
	var position: Vector2=Vector2(first.global_position.x,first.global_position.z)
	return first.linear_velocity.length()<=lessons.handover_maximum_speed and position.distance_to(Vector2(handover_position.x,handover_position.z))<=lessons.handover_parking_radius and position.distance_to(Vector2(second.global_position.x,second.global_position.z))<=lessons.handover_maximum_walk

func exit_allowed(plane: FlightAircraft) -> bool:
	if plane==first and phase in ["RETURN","TAXI_HANDOVER","SHUTDOWN"]:return phase=="SHUTDOWN" and handover_ready()
	return true

func handover_taxi_points() -> Array[Vector3]:
	var field: MaltaAirfield=session.field.fields[session.home_airfield]
	# Cross through the middle gap in the existing AA line, not through the
	# emplacement directly between the runway and the Spitfire's stand.
	var cross_z: float=field.runway_length*.31
	return [field.to_global(Vector3(0,0,cross_z)),field.to_global(Vector3(lessons.handover_apron_x,0,cross_z)),handover_position]

func navigation_label() -> String:
	return "LANDING SECTOR" if phase=="RETURN" else ("TAXI / PARK" if phase in ["TAXI_HANDOVER","SHUTDOWN"] else "LESSON")

func _find_guns() -> void:
	for gun in session.field.aa_battery.guns:
		if String(gun.name).begins_with(session.home_airfield):guns.append(gun)

func _build_results() -> void:
	results=PanelContainer.new();session.malta_mission.canvas.add_child(results)
	results.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	results.offset_left=-230;results.offset_right=230;results.offset_top=-100;results.offset_bottom=110
	results.add_theme_stylebox_override("panel",session.gameplay_hud.panel_style())
	var box:=VBoxContainer.new();results.add_child(box)
	result_title=Label.new();result_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(result_title)
	for caption in ["Retry tutorial","Return to poster"]:
		var button:=Button.new();button.text=caption;box.add_child(button)
		if caption.begins_with("Retry"):button.pressed.connect(func():choose_result(true))
		else:button.pressed.connect(func():choose_result(false))
	results.hide()

func choose_result(retry: bool) -> void:
	if result_transition_queued or not is_finished():return
	result_transition_queued=true
	for button in results.find_children("*","Button",true,false):button.disabled=true
	session.call_deferred("restart_malta" if retry else "show_selection")

func _input(event: InputEvent) -> void:
	if get_tree().paused or GameplayHUD.blocks_input() or is_finished() or event.is_echo() or session.malta_mission.occupied==null:return
	for action in ["throttle_up","throttle_down","pitch_up","pitch_down","roll_left","roll_right","rudder_left","rudder_right","brake","navigation_map"]:
		if event.is_action_pressed(action):practised[action]=true

func advance(next: String) -> void:
	if is_finished():return
	phase=next;settled=0;visited[next]=true
	if next=="TAXI_HANDOVER":
		var local: Vector3=session.field.fields[session.home_airfield].to_local(first.global_position)
		handover_taxi_index=2 if local.x>45 else 0

func is_finished() -> bool:return cancelled or phase in ["SUCCESS","FAILED"]
func cancel() -> void:
	cancelled=true
	if is_instance_valid(siren):siren.stop()
	if is_instance_valid(marker):marker.queue_free()
	if is_instance_valid(results):results.queue_free()

func allowed_aircraft(plane: FlightAircraft) -> bool:
	return plane==(second if phase in ["BOARD_SECOND","SECOND_ENGINE","SECOND_TAKEOFF","DEVICES","FAILURE_ROUTE","EMERGENCY","EXIT_DAMAGED"] else first) and phase not in ["FIRST_RECOVERY","CALL_TRANSPORT","TRUCK","MOUNT_AA","AA_COMBAT","DRAINING","SUCCESS","FAILED"]

func transport_allowed() -> bool:
	if phase=="FIRST_RECOVERY" and session.malta_mission.occupied==null:return true
	return emergency_landed and phase in ["CALL_TRANSPORT","TRUCK"] and session.malta_mission.occupied==null

func _physics_process(delta: float) -> void:
	if get_tree().paused or is_finished():return
	elapsed+=delta
	var mission: MaltaMission=session.malta_mission
	if not mission.survival.alive():finish(false,"Pilot lost — retry the tutorial");return
	var plane: FlightAircraft=mission.occupied
	var required: FlightAircraft=first if phase in ["BOARD","ENGINE","TAXI","TAKEOFF","NAVIGATION","AIR_COMBAT","RETURN","TAXI_HANDOVER","SHUTDOWN"] else (second if phase in ["BOARD_SECOND","SECOND_ENGINE","SECOND_TAKEOFF","DEVICES","FAILURE_ROUTE","EMERGENCY","EXIT_DAMAGED"] else null)
	if is_instance_valid(required) and (required.is_crashed or required.is_destroyed):finish(false,"Lesson aircraft lost — retry for a gentler landing");return
	if is_instance_valid(plane) and (plane.is_crashed or plane.is_destroyed):finish(false,"Aircraft lost — retry and aim for a gentler landing");return
	if phase=="BOARD" and plane==first:advance("ENGINE")
	elif phase=="ENGINE" and first.engine_running:advance("TAXI")
	elif phase=="TAXI" and taxi_ready():advance("TAKEOFF")
	elif phase=="TAKEOFF" and first.altitude>lessons.minimum_flight_agl and first.gear.contact_count==0:advance("NAVIGATION")
	elif phase=="NAVIGATION" and plane==first:
		if first.gear.contact_count==0 and first.altitude>lessons.minimum_flight_agl and first.global_position.distance_to(route[route_index])<lessons.checkpoint_radius:
			if route_index==0 and not handling_practised():return
			route_index+=1
			if route_index==route.size():
				advance("AIR_COMBAT");spawn_stuka(false)
	elif phase=="RETURN" and landed(first,session.home_airfield,delta):advance("TAXI_HANDOVER")
	elif phase=="TAXI_HANDOVER":
		if first.components.power_factor()<lessons.handover_minimum_taxi_power and session.malta_mission.return_flow.landed_field(first)==session.home_airfield:
			advance("FIRST_RECOVERY");return
		var waypoints:=handover_taxi_points()
		if first.global_position.distance_to(waypoints[handover_taxi_index]+Vector3.UP)<10 and handover_taxi_index<2:handover_taxi_index+=1
		settled=settled+delta if handover_ready() else 0
		if settled>=lessons.landing_settle_seconds:advance("SHUTDOWN")
	elif phase=="SHUTDOWN":
		if mission.occupied==null:advance("BOARD_SECOND")
		elif not handover_ready():advance("TAXI_HANDOVER")
	elif phase=="FIRST_RECOVERY" and mission.recovery.returns>recovery_returns and mission.recovery.state=="IDLE":advance("BOARD_SECOND")
	elif phase=="BOARD_SECOND" and plane==second:advance("SECOND_ENGINE")
	elif phase=="SECOND_ENGINE" and second.engine_running:advance("SECOND_TAKEOFF")
	elif phase=="SECOND_TAKEOFF" and second.altitude>lessons.minimum_flight_agl and second.gear.contact_count==0:advance("DEVICES")
	elif phase=="DEVICES" and plane==second:
		gear_retracted_seen=gear_retracted_seen or not second.gear.extended
		flap_deployed_seen=flap_deployed_seen or second.devices.flaps>.8
		if gear_retracted_seen and flap_deployed_seen and second.devices.flaps<.05:advance("FAILURE_ROUTE")
	elif phase=="FAILURE_ROUTE" and plane==second and second.altitude>lessons.emergency_setup_height-120 and second.global_position.distance_to(emergency_setup())<lessons.emergency_capture_radius:
		apply_training_damage();advance("EMERGENCY")
	elif phase=="EMERGENCY" and landed(second,"luqa",delta):emergency_landed=true;advance("EXIT_DAMAGED")
	elif phase=="EXIT_DAMAGED" and mission.occupied==null:advance("CALL_TRANSPORT")
	elif phase=="CALL_TRANSPORT" and mission.recovery.requests>0 and mission.recovery.state!="IDLE":advance("TRUCK")
	elif phase=="TRUCK" and mission.recovery.returns>recovery_returns and mission.recovery.state=="IDLE":advance("MOUNT_AA")
	elif phase=="MOUNT_AA" and guns.has(mission.interaction.occupied_gun):
		advance("AA_COMBAT");spawn_stuka(true)
	elif phase=="AA_COMBAT" and guns.all(func(g):return g.is_destroyed):finish(false,"Battery lost — retry the tutorial")
	elif phase=="DRAINING" and outstanding_bombs()==0:finish(true,"Tutorial complete — flight, combat, emergency landing, recovery and AA qualified")

func taxi_ready() -> bool:
	if first.altitude>lessons.minimum_flight_agl and first.gear.contact_count==0:return true
	var field: MaltaAirfield=session.field.fields[session.home_airfield]
	var local: Vector3=field.to_local(first.global_position)
	return absf(local.x)<22 and absf(local.z)<field.runway_length*.5 and (-first.global_basis.z).dot(-field.global_basis.z)>.9 and first.airspeed>1 and first.pilot.throttle>.15

func handling_practised() -> bool:
	for group in [["pitch_up","pitch_down"],["roll_left","roll_right"],["rudder_left","rudder_right"],["throttle_down"],["navigation_map"]]:
		if not group.any(func(key):return practised.has(key)):return false
	return true

func landed(plane: FlightAircraft,field_id: String,delta: float) -> bool:
	settled=settled+delta if session.malta_mission.return_flow.landed_field(plane)==field_id else 0
	return settled>=lessons.landing_settle_seconds

func above_terrain(point: Vector3,clearance: float) -> Vector3:
	var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x,4000,point.z),Vector3(point.x,-100,point.z),1))
	point.y=maxf(point.y,(float(hit.position.y) if not hit.is_empty() else 0)+clearance)
	return point

func emergency_setup() -> Vector3:
	var field: MaltaAirfield=session.field.fields["luqa"]
	return above_terrain(field.to_global(Vector3(0,lessons.emergency_setup_height,field.runway_length*.5+lessons.emergency_setup_distance)),lessons.emergency_setup_height)

func apply_training_damage() -> void:
	if damage_applied:return
	damage_applied=true;damage_count+=1
	# Explicit scripted mechanical failure, not a fabricated enemy projectile.
	for id in [&"engine",&"left_wing",&"right_wing",&"elevator"]:
		var config: AircraftComponentDefinition=second.components.definitions[id]
		var fraction: float=1.0 if id==&"engine" else (lessons.elevator_damage_fraction if id==&"elevator" else lessons.wing_damage_fraction)
		second.components.apply_damage(id,config.max_integrity*fraction/maxf(config.damage_multiplier,.001),second.global_position,false,"training")
	second.take_damage(maxf(second.health.hp-lessons.damaged_hull_hp,0))

func spawn_stuka(ground_attack: bool) -> void:
	if is_finished() or is_instance_valid(foe) and not foe.is_destroyed:return
	var anchor: Vector3=first.global_position
	if ground_attack:
		centre=session.field.fields[session.home_airfield].global_position
		anchor=centre
	var direction: Vector3=Vector3(1,0,-.25).normalized() if not ground_attack else -session.field.fields[session.home_airfield].global_basis.z
	var point:=above_terrain(anchor+direction*(1600 if ground_attack else 1000),400 if ground_attack else 250)
	if not ground_attack:point.y=maxf(point.y,first.global_position.y+40)
	foe=session.create_encounter_enemy(point,false)
	foe.ai.aim_error_degrees=lessons.enemy_aim_error_degrees
	foe.ai.burst_rest=lessons.enemy_burst_rest
	foe.ai.grace_period=lessons.enemy_grace_seconds
	foe.ai.evade_on_rear_threat=false
	foe.ai.maximum_tactical_bank_degrees=30
	foe.ai.patrol_radius=500
	foe.rear_gunner.set_skill(0)
	if ground_attack:
		var old:=foe.ai;foe.remove_child(old);old.queue_free()
		var ai:=DiveAttackPilot.new();ai.aircraft=foe;ai.director=self
		ai.bomb_error=definition.normal_bomb_error;ai.strafe_error=3;ai.attack_delay=12
		foe.ai=ai;foe.add_child(ai)
		foe.guns.pool.hit_mask|=16
		foe.rear_gunner.enabled=false
		var dive_sound:=StukaDiveAudio.new();dive_sound.aircraft=foe;dive_sound.director=self;foe.add_child(dive_sound)
	var heading: Vector3=((anchor-point)*Vector3(1,0,1)).normalized()
	foe.pending_reset_pose=Transform3D(Basis.looking_at(heading),point)
	foe.pending_reset_velocity=heading*58
	session.encounters.track_enemy(foe)
	foe.destroyed.connect(_enemy_destroyed.bind(foe))
	session.encounters.set_target(session.malta_mission.occupied)
	session.encounter_tracking_changed();spawn_count+=1;siren.set_active(true)

func _enemy_destroyed(source: EnemyAircraft) -> void:
	if is_finished() or source!=foe:return
	kills+=1;siren.set_active(false)
	if phase=="AIR_COMBAT":advance("RETURN")
	elif phase=="AA_COMBAT":advance("DRAINING")

func choose_target(_slot: int) -> BritishAAGun:
	var mounted: BritishAAGun=session.malta_mission.interaction.occupied_gun
	if guns.has(mounted) and not mounted.is_destroyed:return mounted
	for gun in guns:
		if not gun.is_destroyed:return gun
	return null

func release_bomb(source: EnemyAircraft) -> void:
	if is_finished() or bombs_released>0:return
	var bomb:=MissionBomb.new();bomb.velocity=source.linear_velocity;bomb.impact_effects=effects
	bomb.damage_pilots=true;bomb.pilot_blast_damage=definition.player_blast_damage
	bomb.aa_blast_damage=definition.gun_blast_damage;bomb.aa_blast_radius=definition.bomb_blast_radius
	effects.add_child(bomb);bomb.global_position=source.to_global(Vector3(0,-1.4,1));bombs_released+=1

func outstanding_bombs() -> int:
	return effects.get_children().filter(func(node):return node is MissionBomb and not node.is_queued_for_deletion()).size()

func finish(won: bool,message: String) -> void:
	if is_finished():return
	phase="SUCCESS" if won else "FAILED";reason=message;siren.stop();marker.hide()
	if not session.malta_mission.survival.alive():session.malta_mission.survival.death_panel.hide()
	session.encounters.ended=true
	if is_instance_valid(session.malta_mission.interaction.occupied_gun):session.malta_mission.interaction.leave_gun(true)
	for enemy in session.encounters.active:
		enemy.ai.combat_enabled=false;enemy.pilot.fire=false;enemy.rear_gunner.cease_fire();enemy.rear_gunner.enabled=false
		if enemy.ai is DiveAttackPilot:enemy.ai.set_physics_process(false)
	result_title.text=message;results.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func objective_text() -> String:
	if phase=="AA_COMBAT" and session.malta_mission.interaction.occupied_gun==null:return "Mount another operational AA gun"
	return {"BOARD":"Board the Sea Gladiator","ENGINE":"Start the engine","TAXI":"Release brakes and taxi","TAKEOFF":"Take off and climb","NAVIGATION":"Fly lesson checkpoint %d/%d"%[route_index+1,route.size()],"AIR_COMBAT":"Destroy the Stuka over Valletta","RETURN":"Land in the marked Ta’ Qali runway sector","TAXI_HANDOVER":"Taxi to the Spitfire handover stand","SHUTDOWN":"Parked nearby — shut down and exit","FIRST_RECOVERY":"Unable to taxi — request a short truck recovery","BOARD_SECOND":"Walk to and board the Spitfire","SECOND_ENGINE":"Start the Spitfire engine","SECOND_TAKEOFF":"Take off for the second lesson","DEVICES":"Practise gear and landing flaps","FAILURE_ROUTE":"Fly to the emergency exercise entry","EMERGENCY":"Engine failed — glide onto Luqa runway","EXIT_DAMAGED":"Stop and leave the damaged aircraft","CALL_TRANSPORT":"Call the recovery vehicle","TRUCK":"Enter the recovery truck","MOUNT_AA":"Mount an AA gun at base","AA_COMBAT":"Defend base against the Stuka","DRAINING":"Wait for the last bomb to clear","SUCCESS":"Tutorial complete","FAILED":"Tutorial failed"}.get(phase,phase)

func instructions() -> String:
	if phase=="AA_COMBAT" and session.malta_mission.interaction.occupied_gun==null:return "The Stuka is still attacking. Approach another surviving base gun and press E. Unoccupied guns stay idle."
	return {"BOARD":"WASD walk, mouse look. Approach the marked Gladiator; E boards it.","ENGINE":"I starts the engine. W adds power; S reduces it. Throttle stays where set.","TAXI":"A/D steer. Space holds wheel brakes on the ground only. Follow the marker onto the runway; keep speed low and align with its far-end marker before full power.","TAKEOFF":"W full power. At 115–135 km/h, gently press Down Arrow to raise the nose. Up Arrow lowers it. Climb through 35 m.","NAVIGATION":"Arrows pitch and bank; A/D rudder; W/S power. Practise each, reduce power once, and open/close M map. Gladiator gear is fixed; it has no flaps or airbrakes. F1 explains all controls.","AIR_COMBAT":"F fires real guns (Ctrl also works). Lead the aircraft; close to 200–350 m. Avoid lingering behind its rear gunner. Keep speed above 110 km/h.","RETURN":"Approach from the southeast end toward the hangars; touch down in the gold runway sector before the apron. M shows LANDING SECTOR. Approach at 115–135 km/h, flare gently and Space brake. Keep the engine running: next, taxi to the green stand near the Spitfire.","TAXI_HANDOVER":"Keep the engine running (I restarts it if you shut it down); use a little W power and A/D to follow the taxi markers through the clear apron crossing. Stop inside the green circle with Space for two seconds. The Spitfire will be a short walk away. Do not exit on the runway.","SHUTDOWN":"You are parked beside the Spitfire hangar. S idle, hold Space, I engine off, E exit. Walk to the marked Spitfire; aircraft damage and fuel are retained.","FIRST_RECOVERY":"The Gladiator has insufficient engine power to taxi. S idle, I engine off if still running, E exit, then V call recovery. Approach the truck and E returns you beside the hangars without a long walk.","BOARD_SECOND":"Follow the marker to the other aircraft. E boards the Spitfire; the Gladiator remains parked.","SECOND_ENGINE":"I engine start; W power. Taxi with A/D and Space brakes.","SECOND_TAKEOFF":"Take off at 160–180 km/h and climb. Keep the Spitfire intact for the emergency exercise.","DEVICES":"G retracts gear. Below 252 km/h, Q deploys flaps; allow them to extend, then Q retracts them. Use S to slow down. B is airbrakes only where fitted; the Spitfire has none.","FAILURE_ROUTE":"Climb to roughly 600 m above sea level, then follow the marker northwest of Luqa. A scripted training engine failure begins there, not enemy damage.","EMERGENCY":"Keep 180–200 km/h initially by lowering the nose. Keep gear/flaps up until the runway is assured; G down, then Q on final below its limit. Begin a gentle flare early if sinking quickly; Space after touchdown. No autopilot or repair is applied.","EXIT_DAMAGED":"S idle and I engine off. Once stopped, E exits. Your damaged Spitfire stays here.","CALL_TRANSPORT":"V requests the existing recovery truck. Wait beside the aircraft; follow the truck marker when it arrives.","TRUCK":"Walk to the arriving truck and press E. This uses the normal recovery transfer to Ta’ Qali, preserving the world and damaged aircraft.","MOUNT_AA":"Follow the gun marker. E mounts a gun; Bofors is recommended. You can walk or drive a base truck (E, WASD, Space brakes).","AA_COMBAT":"Mouse aims the actual barrel; LMB fires; RMB zooms. B toggles Bofors aim assist. Heavy AA needs a fresh click and five-second reload. E dismounts. All unoccupied guns remain idle.","DRAINING":"Enemy destroyed. Stay alive while remaining physical ordnance clears."}.get(phase,reason)

func objective_point() -> Vector3:
	if phase in ["TAXI","TAKEOFF"]:
		var field: MaltaAirfield=session.field.fields[session.home_airfield]
		var local: Vector3=field.to_local(first.global_position)
		if phase=="TAXI" and absf(local.x)>25:return field.to_global(Vector3(78 if local.x>90 else 0,2,local.z))
		return field.to_global(Vector3(0,2,-field.runway_length*.46))
	if phase=="NAVIGATION":return route[mini(route_index,route.size()-1)]
	if (phase=="AIR_COMBAT" or (phase=="AA_COMBAT" and session.malta_mission.interaction.occupied_gun!=null)) and is_instance_valid(foe):return foe.global_position
	if phase in ["BOARD_SECOND","SECOND_ENGINE","SECOND_TAKEOFF","DEVICES"]:return second.global_position+Vector3.UP*3
	if phase=="FAILURE_ROUTE":return emergency_setup()
	if phase=="EMERGENCY":return session.field.fields["luqa"].to_global(Vector3(0,3,200))
	if phase in ["EXIT_DAMAGED","CALL_TRANSPORT"]:return second.global_position+Vector3.UP*3
	if phase in ["TRUCK","FIRST_RECOVERY"] and is_instance_valid(session.malta_mission.recovery.truck):return session.malta_mission.recovery.truck.global_position+Vector3.UP*3
	if phase in ["MOUNT_AA","AA_COMBAT"]:
		for gun in guns:
			if not gun.weapon.heavy and not gun.is_destroyed:return gun.global_position+Vector3.UP*3
	if phase=="RETURN":return landing_position+Vector3.UP*3
	if phase=="TAXI_HANDOVER":return handover_taxi_points()[handover_taxi_index]+Vector3.UP*3
	if phase=="SHUTDOWN":return handover_position+Vector3.UP*3
	return first.global_position+Vector3.UP*3

func _process(_delta: float) -> void:
	handover_visuals.visible=not is_finished() and phase in ["RETURN","TAXI_HANDOVER","SHUTDOWN"]
	landing_outline.visible=phase=="RETURN"
	parking_outline.visible=phase in ["TAXI_HANDOVER","SHUTDOWN"]
	if is_finished() or route.is_empty():marker.hide();return
	var camera:=get_viewport().get_camera_3d()
	if camera==null:marker.hide();return
	var point:=objective_point()
	marker.visible=not camera.is_position_behind(point)
	marker.position=camera.unproject_position(point)-Vector2(80,35)
	var anchor: Node3D=session.malta_mission.occupied if is_instance_valid(session.malta_mission.occupied) else session.malta_mission.pilot
	marker.text=navigation_label()+" · %d m"%roundi(anchor.global_position.distance_to(point))
