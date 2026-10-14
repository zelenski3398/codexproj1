extends SceneTree
var passed:=0
var failed:=0
var impacts: Array[float]=[]
var phases: Dictionary={}
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in range(n):await physics_frame
func check(value: bool,label: String) -> void:
	if value:passed+=1;print("PASS: ",label)
	else:failed+=1;push_error("FAIL: "+label)
func run() -> void:
	var session: Node3D=load("res://main.tscn").instantiate()
	root.add_child(session)
	await frames(8)
	session.start_aa_defence()
	await frames(20)
	var mission: DiveDefenceMission=session.aa_defence
	mission.definition=mission.definition.duplicate()
	# Observation fixture: no bomb injury, to inspect an uninterrupted physical
	# bomb/pullout/strafe cycle. Destructive balance uses normal values elsewhere.
	mission.definition.gun_blast_damage=0
	mission.definition.player_blast_damage=0
	var interaction: AirfieldInteraction=session.malta_mission.interaction
	session.malta_mission.pilot.global_position=interaction.find_exit(mission.guns[0],5)
	await frames(3)
	interaction.mount_gun(mission.guns[0])
	await frames(2)
	mission.clock=.01
	await frames(10)
	var foe: EnemyAircraft=mission.alive[0]
	var ai: DiveAttackPilot=foe.ai
	var pitch_min:=0.0
	var closest:=INF
	for tick in range(14400):
		await physics_frame
		if not is_instance_valid(foe) or foe.is_destroyed:break
		phases[ai.attack_state]=true
		pitch_min=minf(pitch_min,asin(clampf((-foe.global_basis.z).y,-1,1)))
		closest=minf(closest,foe.global_position.distance_to(ai.attack_point))
		for child in mission.effects.get_children():
			if child is MissionBomb and not child.impacted.is_connected(_impact.bind(mission)):
				child.impacted.connect(_impact.bind(mission))
		if tick%600==0:print("ATTACK t=",tick/120.0," state=",ai.attack_state," agl=",foe.altitude," speed=",foe.airspeed," distance=",foe.global_position.distance_to(mission.centre)," shots=",foe.guns.pool.total_spawned," bombs=",mission.bombs_released," reject=",ai.strafe_rejection," angle=",ai.strafe_angle)
		if foe.guns.pool.total_spawned>0 and ai.passes>0:break
	check(phases.has("DIVE") and phases.has("PULL OUT") and phases.has("CIRCLE"),"Stuka executes visible dive, pullout and circle using real force-driven flight")
	check(pitch_min<deg_to_rad(-20) and closest<700,"Aircraft visibly descends toward emplacement rather than level orbiting")
	check(mission.bombs_released==1 and ai.bombs_remaining==0,"Real attack releases exactly one finite bomb; subsequent passes do not replenish")
	check(not impacts.is_empty(),"Actual gravity-driven swept bomb reaches a physical impact")
	check(not foe.is_destroyed and ai.minimum_clearance>50,"Undamaged aircraft recovers with positive terrain clearance")
	check(foe.guns.pool.total_spawned>0 and ai.passes>0,"Surviving Stuka returns for real projectile strafing after its single bomb")
	var final_clearance: float=ai.minimum_clearance
	session.queue_free()
	await frames(8)
	print("DIVE ATTACK RESULT: ",passed,"/",passed+failed," passed; min pitch=",rad_to_deg(pitch_min)," min AGL=",final_clearance," impact distances=",impacts)
	quit(0 if failed==0 else 1)
func _impact(point: Vector3,mission: DiveDefenceMission) -> void:
	var d:=INF
	for gun in mission.guns:d=minf(d,point.distance_to(gun.global_position))
	impacts.append(d)
