extends SceneTree
var passed:=0
var failed:=0
var session: Node3D
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in range(n):await physics_frame
func check(value: bool,label: String) -> void:
	if value:passed+=1;print("PASS: ",label)
	else:failed+=1;push_error("FAIL: "+label)
func reset() -> DiveDefenceMission:
	session.restart_malta()
	await frames(16)
	session.aa_defence.definition=session.aa_defence.definition.duplicate()
	return session.aa_defence
func mount(gun: BritishAAGun) -> bool:
	var interaction: AirfieldInteraction=session.malta_mission.interaction
	session.malta_mission.pilot.global_position=interaction.find_exit(gun,5)
	await frames(3)
	return interaction.mount_gun(gun)
func run() -> void:
	session=load("res://main.tscn").instantiate()
	root.add_child(session)
	await frames(6)
	session.show_missions()
	var mission_names: Array[String] = []
	for index in session.missions_menu.mission_picker.item_count:
		mission_names.append(session.missions_menu.mission_picker.get_item_text(index))
	check(mission_names == ["Defend Valletta — Ta’ Qali Interception", "Under Dive-Bomber Attack — Ħal Luqa", "Faith, Hope and Charity — Harbour Interception"], "Missions menu preserves interception and AA choices and includes harbour interception")
	session.missions_menu.mission_picker.select(1)
	session.missions_menu._choose_mission(1)
	check(session.missions_menu.briefing.text==DiveDefenceMission.BRIEFING and session.missions_menu.aircraft_picker.disabled,"AA briefing and ground departure selection")
	session.start_aa_defence()
	await frames(20)
	var mission: DiveDefenceMission=session.aa_defence
	var controls: AirfieldInteraction=session.malta_mission.interaction
	var pilot: GroundPilot=session.malta_mission.pilot
	check(session.home_airfield=="luqa" and mission.guns.size()==6 and session.field.aa_battery.guns.size()==18,"Luqa uses exactly its four heavy and two light emplacements; no duplicate guns")
	await frames(240)
	check(mission.phase=="WAIT_MOUNT" and mission.wave==0 and mission.total_spawned==0,"First wave waits indefinitely for first mount")
	Input.action_press("fire")
	await frames(30)
	Input.action_release("fire")
	check(session.field.aa_battery.guns.all(func(g):return g.shots_fired==0),"All unoccupied guns remain manual-only")
	check(await mount(mission.guns[0]),"Nearby operational gun can be mounted")
	await frames(3)
	check(mission.phase=="PREPARING" and mission.clock>3 and mission.total_spawned==0,"First mount starts short preparation countdown without premature spawn")
	check(pilot.collision_layer==16 and not pilot.active and pilot.global_position.distance_to(mission.guns[0].global_position)<3,"Mounted operator retains actual local live damage capsule")
	mission.definition=mission.definition.duplicate()
	mission.clock=.01
	await frames(10)
	check(mission.alive.size()==1 and mission.wave==1,"Wave 1 spawns one Stuka")
	var foe: EnemyAircraft=mission.alive[0]
	check(foe.ai is DiveAttackPilot and foe.health.hp==100 and (foe.guns.pool.hit_mask&16)!=0,"Stuka reuses physical airframe, normal health, swept guns and player hit detection")
	check(foe.global_position.distance_to(pilot.global_position)>1200 and foe.altitude>500,"Initial Stuka has fair distance and safe terrain clearance")
	var enemy_position: Vector3=foe.global_position
	controls.leave_gun()
	var truck: MilitaryTruck=session.malta_mission.world.trucks[1]
	pilot.global_position=truck.global_position+truck.global_basis.x*2.5+Vector3.UP
	await frames(3)
	var entered: bool=controls.enter_vehicle(truck)
	var truck_start: Vector3=truck.global_position
	Input.action_press("throttle_up")
	await frames(180)
	Input.action_release("throttle_up")
	Input.action_press("brake")
	await frames(60)
	Input.action_release("brake")
	check(entered and truck.global_position.distance_to(truck_start)>2,"Damageable seated driver does not block own truck; ordinary controls drive during attack")
	check(foe.global_position.distance_to(enemy_position)>40 and mission.wave==1 and mission.alive.has(foe),"Stuka attack and wave persist during gun → truck travel")
	controls.leave_vehicle()
	await mount(mission.guns[0])
	foe.freeze=true
	foe.ai.set_physics_process(false)
	var before: float=pilot.health.hp
	foe.guns.pool.spawn(pilot.global_position+mission.guns[0].global_basis.x*15,-mission.guns[0].global_basis.x*650,1,12,foe.get_rid(),true,CombatTeams.ENEMY)
	await frames(10)
	check(pilot.health.hp<before,"Real swept enemy gunfire can injure mounted operator")
	before=pilot.health.hp
	var gun_hp: float=mission.guns[0].hp
	foe.guns.pool.spawn(mission.guns[0].global_position+Vector3.UP*20,Vector3.DOWN*650,1,foe.guns.bullet_damage,foe.get_rid(),true,CombatTeams.ENEMY)
	await frames(10)
	check(mission.guns[0].hp<gun_hp,"Actual enemy strafe projectile can damage emplacement collision")
	gun_hp=mission.guns[0].hp
	var bomb:=MissionBomb.new()
	bomb.damage_pilots=true
	bomb.pilot_blast_damage=30
	bomb.aa_blast_damage=40
	bomb.impact_effects=mission.effects
	mission.effects.add_child(bomb)
	bomb.explode(mission.guns[0].global_position+Vector3(5,0,0))
	var after: float=pilot.health.hp
	bomb.explode(mission.guns[0].global_position)
	check(after<before and pilot.health.hp==after and mission.guns[0].hp<gun_hp,"Bomb blast independently damages gun/operator exactly once")
	var retained: float=mission.guns[0].hp
	controls.leave_gun()
	await frames(4)
	check(await mount(mission.guns[0]) and mission.guns[0].hp==retained,"Dismount/re-entry preserves damaged gun and player health")
	mission.guns[0].take_damage(1000)
	await frames(8)
	check(pilot.active and controls.occupied_gun==null and pilot.health.hp==after and not mission.is_finished(),"Surviving operator exits destroyed gun without healing or automatic remount")
	check(await mount(mission.guns[1]),"Survivor can approach and mount second gun")
	for gun in mission.guns:
		gun.take_damage(1000)
	await frames(6)
	check(mission.phase=="FAILED" and mission.result_count==1,"Both local guns lost fails once despite four other Malta guns")
	mission=await reset()
	check(mission.phase=="WAIT_MOUNT" and mission.wave==0 and mission.total_spawned==0 and mission.outstanding_ordnance()==0,"Retry clears waves/enemies/ordnance and waits for mount")
	check(mission.guns.all(func(g):return g.hp==150 and not g.mounted) and session.malta_mission.pilot.health.hp==100,"Retry restores both guns/operator and exclusive walking control")
	await mount(mission.guns[0])
	await frames(3)
	mission.clock=.01
	await frames(10)
	# Exact progression uses actual destruction events; no damage-free smoke shortcut.
	for wave in range(1,7):
		check(mission.wave==wave and mission.alive.size()==DiveDefenceMission.WAVES[wave-1],"Exact batch count for wave %d"%wave)
		for enemy in mission.alive:
			enemy.freeze=true
			enemy.ai.set_physics_process(false)
		if mission.alive.is_empty():break
		if wave==6:
			var ace: EnemyAircraft=mission.alive[0]
			check(ace.encounter_ace and ace.marker_name=="STUKA" and ace.health.max_hp==100 and ace.ai.bomb_error<mission.definition.normal_bomb_error and ace.ai.recovery_seconds<mission.definition.normal_recovery_seconds,"Final ace uses ordinary capabilities/HP with configurable better aim and recovery")
		if wave==6:
			var last: EnemyAircraft=mission.alive[0]
			last.guns.pool.spawn(Vector3(8000,1000,8000),Vector3.FORWARD*200,.5,2,last.get_rid(),true,CombatTeams.ENEMY)
		var falling:=MissionBomb.new()
		falling.impact_effects=mission.effects
		mission.effects.add_child(falling)
		falling.set_physics_process(false)
		var survivors:=mission.alive.duplicate()
		for enemy in survivors:enemy.take_damage(1000)
		await frames(5)
		check(mission.phase=="DRAINING" and not mission.results.visible,"Wave %d waits for unresolved bomb before interval/victory"%wave)
		falling.queue_free()
		await frames(5)
		if wave==6:
			check(mission.phase=="DRAINING" and mission.outstanding_ordnance()>0 and not mission.results.visible,"Final victory waits for actual airborne hostile rounds retained after shooter destruction")
			await frames(70)
		if wave<6:
			check(mission.phase=="INTERVAL" and mission.clock>9 and mission.wave==wave,"Wave %d starts configurable ten-second interval only after ordnance drains"%wave)
			mission.clock=.01
			await frames(10)
	check(mission.wave_spawn_counts==[1,1,2,2,3,1] and mission.total_spawned==10 and mission.total_destroyed==10,"Exactly ten Stukas in required six-wave sequence")
	check(mission.phase=="SUCCESS" and mission.result_count==1 and mission.results.visible,"Victory requires all ten losses, live operator, surviving gun and drained ordnance")
	mission._resolve()
	check(mission.result_count==1,"Repeated callbacks cannot produce duplicate result panels")
	mission=await reset()
	session.malta_mission.pilot.take_damage(1000)
	await frames(5)
	check(mission.phase=="FAILED" and mission.final_reason=="Operator killed" and mission.total_spawned==0,"Player death immediately fails and prevents pending waves")
	mission=await reset()
	await mount(mission.guns[0])
	var old_gun: BritishAAGun=mission.guns[0]
	var lethal:=MissionBomb.new()
	lethal.damage_pilots=true
	lethal.impact_effects=mission.effects
	mission.effects.add_child(lethal)
	lethal.explode(session.malta_mission.pilot.global_position+Vector3.UP*.5)
	await frames(5)
	check(session.malta_mission.pilot.health.hp==0 and old_gun.is_destroyed and mission.phase=="FAILED" and not session.malta_mission.pilot.active,"Same bomb resolves operator death and occupied gun loss without granting survival")
	session.return_to_missions()
	await frames(6)
	check(session.aa_defence==null and is_instance_valid(session.missions_menu),"Return to Missions tears down AA mission and restores selection")
	session.queue_free()
	await frames(8)
	print("DIVE DEFENCE RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)
