extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in range(n):await physics_frame
func check(ok: bool,label: String) -> void:
	if ok:passed+=1;print("PASS: ",label)
	else:failed+=1;push_error("FAIL: "+label)
func run() -> void:
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	for kind in ["sm79","c200","stuka"]:
		if game.malta_mission!=null:game.restart_malta()
		else:game.start_aa_defence()
		await frames(20)
		var mission: DiveDefenceMission=game.aa_defence
		mission.definition=mission.definition.duplicate()
		mission.definition.gun_blast_damage=0
		mission.definition.player_blast_damage=0
		var station: AACommandStation
		for post in game.field.aa_battery.command_stations:
			if post.field_id=="luqa":station=post
		var interaction: AirfieldInteraction=game.malta_mission.interaction
		game.malta_mission.pilot.global_position=interaction.find_exit(station,3)
		await frames(2)
		interaction.mount_gun(station)
		await frames(2)
		var foe: EnemyAircraft
		if kind=="stuka":
			mission.clock=.01
			await frames(15)
			foe=mission.alive[0]
			for i in range(6000):
				await physics_frame
				if foe.ai.attack_state=="DIVE" and foe.linear_velocity.y< -10:break
			check(foe.ai.attack_state=="DIVE" and foe.linear_velocity.y< -10,"Stuka fixture actually descends toward the staffed command post")
			check(foe.ai.assigned_gun==station,"Existing dive AI can select the player-occupied predictor post as a bombing target")
		else:
			mission.set_physics_process(false)
			var position: Vector3=station.global_position+Vector3(300,650,-1500)
			foe=game.create_encounter_enemy(position,false,kind)
			game.encounters.track_enemy(foe)
			foe.pending_reset_pose=Transform3D(Basis.IDENTITY,position)
			foe.pending_reset_velocity=Vector3(0,0,-65)
			foe.ai.combat_enabled=false
			if foe.ai is BomberPilot:foe.ai.assign_route(position,position+Vector3(0,0,-6500),100)
			else:
				foe.ai.patrol_center=position+Vector3(300,0,0)
				foe.ai.patrol_radius=350
			await frames(1200)
			check(not foe.is_destroyed and foe.linear_velocity.length()>40,kind+": real airframe flies continuously under normal aerodynamic forces")
			if kind=="c200":check(absf(foe.global_basis.x.y)>.1,"Macchi fighter banks through its normal manoeuvring AI")
		station.rng.seed=1940
		station.designate(foe)
		var before: int=game.field.aa_battery.projectiles.total_spawned
		await frames(360)
		check(game.field.aa_battery.projectiles.total_spawned==before,kind+": prediction and automatic slew never autonomously fire")
		check(station.fire_round(),kind+": player firing decision queues a coordinated physical salvo")
		var max_orders: int=station.orders.size()
		var hp_before: float=foe.health.hp
		await frames(1000)
		var rounds: int=game.field.aa_battery.projectiles.total_spawned-before
		check(rounds>0 and rounds<=4 and max_orders<=4,kind+": salvo consists only of independent physical shells; rounds="+str(rounds))
		check(station.prediction_error_metres>0 and station.velocity_error.length()>0,kind+": default prediction uncertainty is enabled")
		print("ENGAGEMENT ",kind," HP lost=",hp_before-foe.health.hp," physical shells=",rounds," remaining orders=",station.orders.size())
	print("BATTERY ENGAGEMENT RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)
