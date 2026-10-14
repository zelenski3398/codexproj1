extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,text: String) -> void:
	if value: passed+=1;print("PASS: ",text)
	else: failed+=1;push_error("FAIL: "+text)
func frames(n: int) -> void:
	for i in range(n): await physics_frame
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	game.start_malta("ta_qali","spitfire","interception")
	await frames(15)
	var battery: AirfieldAABattery = game.field.aa_battery
	check(battery.damage_at_distance(0)==150 and battery.damage_at_distance(6)>battery.damage_at_distance(12) and battery.damage_at_distance(12)>battery.damage_at_distance(20),"Blast strength decreases smoothly from centre to edge")
	check(battery.damage_at_distance(24)==0 and battery.damage_at_distance(100)==0,"No blast damage beyond configured radius")
	var losses: Array[float] = []
	for distance in [2.0,7.0,13.0,30.0]:
		var foe := EnemyAircraft.new()
		game.add_child(foe)
		foe.freeze=true
		foe.reset_pending=false
		foe.global_position=Vector3(1000,600,1000)
		await frames(3)
		# Burst above the outermost cockpit surface. The nearest-hitbox distance
		# is deliberately different from centre-to-plane distance.
		var point: Vector3 = foe.global_position + Vector3(0,1.11+distance,0.55)
		battery._burst(point,null,CombatTeams.PLAYER)
		losses.append(100-foe.health.hp)
		check(foe.components.last_hit!=&"" if distance<15 else foe.components.last_hit==&"","Actual burst damage uses localized component framework at %d m"%distance)
		foe.queue_free()
		await frames(2)
	check(losses[0]>50 and losses[0]>losses[1] and losses[1]>losses[2] and losses[3]==0,"Actual spawned enemy suffers severe nearby, moderate middle, light edge and zero distant damage")
	var foe := EnemyAircraft.new()
	game.add_child(foe)
	foe.freeze=true
	foe.reset_pending=false
	foe.global_position=Vector3(1000,600,1000)
	await frames(3)
	var gun: BritishAAGun = battery.guns[0]
	var centre := foe.global_position + Vector3(0,0,-2.75)
	battery.projectiles.spawn(centre+Vector3(0,0,-20),Vector3(0,0,700),1,gun.direct_damage,gun.get_rid(),true,CombatTeams.PLAYER)
	await frames(8)
	check(foe.is_destroyed and foe.health.hp==0 and foe.components.integrity_ratio(&"engine")==0,"Swept direct AA shell hit destroys engine and aircraft")
	check(not foe.ai.is_physics_processing() and not foe.guns.external_fire,"Devastating hit uses existing one-shot destruction lifecycle")
	print("FLAK DAMAGE RESULT: ",passed,"/",passed+failed," passed; measured HP losses=",losses)
	quit(0 if failed==0 else 1)
