class_name DiveAttackPilot
extends EnemyPilot
## Navigation targets and ordinary slewed controls only. No pursuit teleports,
## forces, velocities or transforms are assigned by this attack controller.
var director: Node3D
var attack_delay: float = 0
var attack_state: String = "APPROACH"
var clock: float = 0
var state_time: float = 0
var bombs_remaining: int = 1
var passes: int = 0
var assigned_gun: BritishAAGun
var attack_point: Vector3
var run_in_point: Vector3
var run_in_reached: bool=false
var pullout_point: Vector3
var bomb_error: float = 18
var strafe_error: float = 0.9
var recovery_seconds: float = 14
var initial_slot: int = 0
var minimum_clearance: float = INF
var strafe_rejection: String="NOT IN RUN"
var strafe_angle: float=0

func reset() -> void:
	super.reset()
	attack_state="APPROACH"
	clock=0
	state_time=0
	bombs_remaining=1
	passes=0
	minimum_agl=55
	cruise_speed=68
	engage_speed_bonus=0
	measured_terrain=true
	world_extent=INF
	evade_on_damage=false
	terrain_lookahead_seconds=2.0

func _choose_target() -> void:
	assigned_gun=director.choose_target(initial_slot)
	if assigned_gun==null:return
	attack_point=assigned_gun.global_position+Vector3.UP*1.2
	attack_point+=Vector3(rng.randfn(0,bomb_error),0,rng.randfn(0,bomb_error))
	if bombs_remaining==0:
		attack_point=assigned_gun.global_position+Vector3.UP*1.5
		if director.session.malta_mission.interaction.occupied_gun==assigned_gun:
			attack_point=director.session.malta_mission.pilot.global_position
		aim_bias=Vector2(rng.randfn(0,strafe_error),rng.randfn(0,strafe_error))
		var outward: Vector3=((aircraft.global_position-attack_point)*Vector3(1,0,1)).normalized()
		run_in_point=attack_point+outward*(director.definition.ace_run_in_distance if aircraft.encounter_ace else director.definition.normal_run_in_distance)+Vector3.UP*300
		run_in_reached=false

func _change(next: String) -> void:
	attack_state=next
	state_time=0

func _physics_process(delta: float) -> void:
	if not aircraft.reset_pending and not aircraft.is_destroyed and not aircraft.is_crashed and _handle_damage(delta): return
	aircraft.pilot.fire=false
	aircraft.guns.use_assisted_aim=false
	if aircraft.reset_pending or aircraft.is_destroyed or director==null or director.is_finished():return
	clock+=delta
	state_time+=delta
	mode="ENGAGE"
	tactic=attack_state
	var position: Vector3=aircraft.global_position
	var ground: float=_terrain_height(position)
	var agl: float=position.y-ground
	minimum_clearance=minf(minimum_clearance,agl)
	if assigned_gun==null or assigned_gun.is_destroyed:
		_choose_target()
	if assigned_gun==null:return
	var flat: Vector3=(attack_point-position)*Vector3(1,0,1)
	var aim: Vector3=attack_point+Vector3.UP*(director.definition.spawn_height if bombs_remaining>0 else 300)
	if clock<attack_delay:
		patrol_center=director.centre+Vector3.UP*director.definition.spawn_height
		patrol_radius=director.definition.spawn_distance
		aim=_patrol_point()
		tactic="FORMING ATTACK"
	elif attack_state=="APPROACH":
		if state_time<delta*2:_choose_target()
		aim=attack_point+Vector3.UP*(director.definition.spawn_height if bombs_remaining>0 else 300)
		if bombs_remaining==0 and not run_in_reached:
			aim=run_in_point
			tactic="POSITIONING FOR STRAFE"
			if ((run_in_point-position)*Vector3(1,0,1)).length()<500:run_in_reached=true
		var forward: Vector3=(-aircraft.global_basis.z*Vector3(1,0,1)).normalized()
		if (bombs_remaining>0 or run_in_reached) and flat.length()<(1100 if bombs_remaining>0 else 1200) and forward.angle_to(flat)<deg_to_rad(25 if bombs_remaining>0 else (director.definition.ace_entry_alignment_degrees if aircraft.encounter_ace else director.definition.normal_entry_alignment_degrees)):
			_change("DIVE")
	elif attack_state=="DIVE":
		aim=attack_point if bombs_remaining>0 else attack_point-aircraft.linear_velocity*(flat.length()/aircraft.guns.bullet_speed)
		var fall_time: float=(aircraft.linear_velocity.y+sqrt(pow(aircraft.linear_velocity.y,2)+2*9.81*maxf(agl,0)))/9.81
		var impact: Vector3=position+aircraft.linear_velocity*fall_time
		var miss: float=((impact-attack_point)*Vector3(1,0,1)).length()
		if bombs_remaining>0 and (miss<(7 if aircraft.encounter_ace else 12) or agl<director.definition.bomb_release_minimum_agl or flat.length()<250):
			bombs_remaining=0 # latch before creating finite ordnance
			director.release_bomb(aircraft)
			_begin_pullout()
		elif bombs_remaining==0:
			_strafe(delta)
			if agl<director.definition.pullout_minimum_agl or flat.length()<230 or state_time>18:_begin_pullout()
	elif attack_state=="PULL OUT":
		aim=pullout_point
		if state_time>7 and aircraft.linear_velocity.y>-2 and agl>200:
			_change("CIRCLE")
	elif attack_state=="CIRCLE":
		patrol_center=director.centre+Vector3.UP*director.definition.spawn_height
		patrol_radius=1250
		aim=_patrol_point()
		if state_time>recovery_seconds:
			passes+=1
			_choose_target()
			_change("APPROACH")
	# Dive uses a shorter terrain forecast and a positive, generous release
	# floor. Recovery/approach retain the shared terrain-corridor protection.
	terrain_avoiding=false
	if attack_state!="DIVE":
		scan_clock-=delta
		if scan_clock<=0:
			_scan_terrain()
			scan_clock=.15
		if terrain_avoiding:aim=avoidance_point
	elif agl<director.definition.pullout_minimum_agl:
		_begin_pullout()
		aim=pullout_point
	var previous_pitch_command: float=aircraft.pilot.pitch
	_fly_toward(aim,delta)
	if attack_state=="DIVE":
		# Shared navigation limits shallow patrol pitch. A dive needs a steeper
		# nose command, still through the same elevator torque and rate damping.
		var forward: Vector3=-aircraft.global_basis.z
		var desired: float=clampf(atan2(aim.y-position.y,maxf(((aim-position)*Vector3(1,0,1)).length(),1)),-deg_to_rad(32 if bombs_remaining>0 else 42),.1)
		var pitch: float=asin(clampf(forward.y,-1,1))
		var omega: Vector3=aircraft.global_basis.transposed()*aircraft.angular_velocity
		var control: float=clampf(((desired-pitch)*4-omega.x*.8)/maxf(aircraft.components.elevator_factor()*aircraft.components.cockpit_factor(),compensation_authority_floor),-1,1)
		if absf(omega.x)>maximum_pitch_rate:control=-signf(omega.x)
		aircraft.pilot.pitch=move_toward(previous_pitch_command,control,delta*command_slew_rate)
		aircraft.pilot.throttle=.45

func _begin_pullout() -> void:
	var ahead: Vector3=(-aircraft.global_basis.z*Vector3(1,0,1)).normalized()
	pullout_point=aircraft.global_position+ahead*1100+Vector3.UP*500
	_change("PULL OUT")

func _strafe(_delta: float) -> void:
	var offset: Vector3=attack_point-aircraft.global_position
	if offset.length()>firing_range:
		strafe_rejection="RANGE"
		return
	var lead: Vector3=attack_point-aircraft.linear_velocity*(offset.length()/aircraft.guns.bullet_speed)
	var biased: Vector3=(lead-aircraft.global_position).rotated(aircraft.global_basis.x,deg_to_rad(aim_bias.x)).rotated(aircraft.global_basis.y,deg_to_rad(aim_bias.y))
	strafe_angle=rad_to_deg((-aircraft.global_basis.z).angle_to(biased))
	if strafe_angle>firing_cone_degrees:
		strafe_rejection="CONE"
		return
	for port in aircraft.model.gun_ports:
		var query:=PhysicsRayQueryParameters3D.create(port.global_position,attack_point,17,[aircraft.get_rid()])
		var hit:=aircraft.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider!=assigned_gun and hit.collider!=director.session.malta_mission.pilot:
			strafe_rejection="OBSTRUCTION "+String(hit.collider.name)
			return
	strafe_rejection="BURST"
	aircraft.pilot.fire=fposmod(state_time,1.8)<.8
	aircraft.guns.use_assisted_aim=aircraft.pilot.fire
	aircraft.guns.max_assist_degrees=firing_cone_degrees
	aircraft.guns.assisted_aim=aircraft.global_position+biased
