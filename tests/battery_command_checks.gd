extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in range(n):await physics_frame
func check(ok: bool,label: String) -> void:
	if ok:passed+=1;print("PASS: ",label)
	else:failed+=1;push_error("FAIL: "+label)
func key(pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=KEY_F
	event.keycode=KEY_F
	event.pressed=pressed
	Input.parse_input_event(event)
func run() -> void:
	for velocity in [Vector3.ZERO,Vector3(100,0,0),Vector3(-45,-60,20)]:
		var point:=Vector3(300,650,-1800)
		var origin:=Vector3(0,100,0)
		var solution:=AAFireControl.solve(origin,point,velocity,790,9.81,8)
		var t: float=solution.time
		var arrival: Vector3=origin+solution.direction*790*t+Vector3.DOWN*.5*9.81*t*t
		check(solution.valid and arrival.distance_to(point+velocity*t)<.02,"Ballistic lead + gravity intercept moving target "+str(velocity))
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	game.start_aa_defence()
	await frames(20)
	var mission: DiveDefenceMission=game.aa_defence
	mission.set_physics_process(false)
	var battery: AirfieldAABattery=game.field.aa_battery
	check(battery.guns.size()==18 and battery.command_stations.size()==3,"One post per four-heavy/two-Bofors airfield; no extra guns")
	var station: AACommandStation
	for post in battery.command_stations:
		check(post.battery_guns.size()==4 and post.battery_guns.all(func(g):return g.weapon.heavy),"Each command post owns only its four local heavy guns")
		if post.field_id=="luqa":station=post
	var interaction: AirfieldInteraction=game.malta_mission.interaction
	check(not interaction.mount_gun(station),"Remote command-station mounting rejected")
	game.malta_mission.pilot.global_position=interaction.find_exit(station,3)
	await frames(2)
	check("F Enter Heavy AA" in interaction.prompt(),"Nearby soldier receives explicit F command prompt")
	key(true)
	await frames(3)
	key(false)
	await frames(3)
	check(interaction.occupied_gun==station and station.mounted and not game.malta_mission.pilot.active,"F transfers exclusive controller to battery commander")
	check(station.salvos_issued==0 and battery.projectiles.total_spawned==0,"F entering the post never fires despite legacy F gun alias")
	var foe:=EnemyAircraft.new()
	game.add_child(foe)
	foe.freeze=true
	foe.reset_pending=false
	foe.ai.set_physics_process(false)
	foe.rear_gunner.set_physics_process(false)
	foe.global_position=station.global_position+Vector3(0,500,-1500)
	await frames(3)
	station.prediction_error_metres=0
	station.velocity_error_mps=0
	station.gun_difference_metres=0
	station.tracking_delay=0
	# Ideal-condition collision fixture; imperfect combat is tested separately.
	for gun in station.battery_guns:gun.aim_error_degrees=0
	station.designate(foe)
	await frames(400)
	check(battery.projectiles.total_spawned==0 and station.orders.is_empty(),"Designation rotates guns but cannot initiate firing")
	check(station.solutions.size()==4 and station.solutions.values().all(func(s):return s.valid and s.aimable),"Each gun gets its own valid lead/elevation/fuze solution")
	var before:=battery.projectiles.total_spawned
	check(station.fire_round() and not station.fire_round(),"One explicit order queues one salvo; duplicate presses cannot stack it")
	var fired: Array[int]=[]
	var last:=before
	for tick in range(900):
		await physics_frame
		if battery.projectiles.total_spawned!=last:fired.append(tick);last=battery.projectiles.total_spawned
		if last-before==4:break
	check(battery.projectiles.total_spawned-before==4 and fired.size()==4,"Four distinct physical gun barrels fire four swept ballistic shells")
	check(fired[3]-fired[0]>=90,"Configured stagger separates first/last reports by at least 0.75 seconds")
	check(station.battery_guns.all(func(g):return g.cooldown>3.5 and g.cooldown<=5),"Each gun independently starts its five-second automatic reload")
	check(station.battery_guns.all(func(g):return g.fuze_seconds>1 and g.fuze_seconds<4),"Per-gun timed fuzes reflect physical flight time")
	await frames(420)
	check(foe.is_destroyed,"Actual heavy-shell direct/proximity collision can destroy the 100 HP Stuka")
	var count: int=battery.projectiles.total_spawned
	await frames(650)
	check(battery.projectiles.total_spawned==count,"Ready loaded guns never fire again without a new player order")
	station.designate_area(station.global_position+Vector3(0,700,-1800))
	check(station.fire_round(),"A fresh loaded salvo can be ordered after the target is lost")
	station.battery_guns[0].take_damage(1000)
	await frames(900)
	check(station.orders.is_empty(),"A gun destroyed during a queued salvo cannot deadlock future firing orders")
	station.designate_area(station.global_position+Vector3(0,1800,-12000))
	await frames(500)
	check(station.solutions.values().any(func(s):return not s.valid and s.aimable),"Distant designated area can be physically aimable without a perfect intercept")
	before=battery.projectiles.total_spawned
	check(station.fire_round(),"Commander can explicitly order an approximate barrage")
	await frames(240)
	check(battery.projectiles.total_spawned-before==3,"Destroyed heavy gun is excluded; surviving three still fire")
	station.designate_area(station.global_position+Vector3(500,400,-1300))
	await frames(650)
	check(station.fire_round(),"Fresh explicit salvo after independent reload")
	var hp: Array=station.battery_guns.map(func(g):return g.hp)
	key(true)
	await frames(4)
	key(false)
	await frames(4)
	count=battery.projectiles.total_spawned
	await frames(800)
	check(interaction.occupied_gun==null and game.malta_mission.pilot.active and station.orders.is_empty() and battery.projectiles.total_spawned==count,"F dismount cancels queued orders, restores walking and prevents autonomous fire")
	check(station.battery_guns.map(func(g):return g.hp)==hp,"Command entry/exit preserves every gun's independent damage")
	game.malta_mission.pilot.global_position=interaction.find_exit(station,3)
	await frames(2)
	interaction.mount_gun(station)
	var surviving: int=station.battery_guns.filter(func(g):return not g.is_destroyed).size()
	station.take_damage(1000)
	await frames(4)
	check(station.is_destroyed and interaction.occupied_gun==null and game.malta_mission.pilot.active,"Post destruction safely ejects commander")
	check(station.battery_guns.filter(func(g):return not g.is_destroyed).size()==surviving,"Losing predictor post does not destroy surviving guns")
	var manual: BritishAAGun=station.battery_guns[1]
	game.malta_mission.pilot.global_position=interaction.find_exit(manual,5)
	await frames(2)
	check(interaction.mount_gun(manual),"Individual gun operation remains available after command-post loss")
	interaction.leave_gun()
	game.restart_malta()
	await frames(20)
	check(game.field.aa_battery.command_stations.size()==3 and get_nodes_in_group("friendly_aa_commands").size()==3,"Retry restores exactly three command posts without duplicates")
	check(game.field.aa_battery.command_stations.all(func(p):return p.hp==p.max_hp and p.orders.is_empty()),"Retry resets post health, orders and gun control ownership")
	var restored: AACommandStation
	for post in game.field.aa_battery.command_stations:
		if post.field_id=="luqa":restored=post
	game.malta_mission.pilot.global_position=game.malta_mission.interaction.find_exit(restored,3)
	await frames(2)
	game.malta_mission.interaction.mount_gun(restored)
	await frames(2)
	var bomb:=MissionBomb.new()
	bomb.impact_effects=game
	bomb.damage_pilots=true
	game.add_child(bomb)
	bomb.explode(game.malta_mission.pilot.global_position)
	await frames(5)
	check(restored.is_destroyed and game.malta_mission.pilot.health.hp==0,"An actual direct bomb blast can destroy command post and kill its operator")
	check(restored.battery_guns.any(func(g):return not g.is_destroyed),"Bomb damage remains distance based; surviving battery guns are not automatically lost")
	check(game.aa_defence.phase=="FAILED" and game.aa_defence.result_count==1,"Commander death preserves immediate one-shot mission failure")
	print("BATTERY COMMAND RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)
