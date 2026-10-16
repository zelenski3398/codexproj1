extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok:passed+=1;print("PASS: ",message)
	else:failed+=1;push_error("FAIL: "+message)
func frames(n: int) -> void:
	for i in range(n):await physics_frame
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	game.start_malta("luqa","spitfire","aa_defence")
	await frames(20)
	var battery: AirfieldAABattery = game.field.aa_battery
	check(battery.guns.size()==18,"Three airfields each have six independent guns")
	for field in game.field.fields.values():
		var heavy := 0
		var light := 0
		for gun in battery.guns:
			if not gun.name.begins_with(field.record.id):continue
			if gun.weapon.heavy:heavy+=1
			else:light+=1
			check(field.to_local(gun.global_position).x>32,"Emplacement stays outside runway")
		check(heavy==4 and light==2,"Four heavy and two Bofors at "+field.record.id)
	var heavy: BritishAAGun = game.aa_defence.guns[0]
	var light: BritishAAGun = game.aa_defence.guns[4]
	# No scripted attacks during weapon instrumentation; mounting remains real.
	game.aa_defence.set_physics_process(false)
	for gun in game.aa_defence.guns:
		game.malta_mission.pilot.global_position=gun.global_position+Vector3(5,1.05,0)
		await frames(2)
		check(game.malta_mission.interaction.mount_gun(gun),"Mount "+gun.weapon.display_name)
		gun.take_damage(10)
		check(game.malta_mission.interaction.leave_gun() and gun.hp==140,"Exit preserves individual damage")
	game.malta_mission.pilot.global_position=heavy.global_position+Vector3(5,1.05,0)
	await frames(2)
	game.malta_mission.interaction.mount_gun(heavy)
	Input.action_press("fire")
	await frames(650)
	check(heavy.shots_fired==1,"Held trigger never repeats heavy fire, even after reload")
	Input.action_release("fire")
	await frames(2)
	Input.action_press("fire")
	await frames(2)
	Input.action_release("fire")
	check(heavy.shots_fired==2 and heavy.cooldown>4.9,"Fresh press fires next heavy shell and starts five-second reload")
	check(heavy.projectile_speed==790 and battery.projectiles.gravity==9.81,"Heavy velocity and ballistic gravity")
	game.malta_mission.interaction.leave_gun()
	game.malta_mission.pilot.global_position=light.global_position+Vector3(5,1.05,0)
	await frames(2)
	game.malta_mission.interaction.mount_gun(light)
	Input.action_press("fire")
	await frames(190)
	check(light.shots_fired==4,"Bofors fires four shots at 0.5 second spacing")
	await frames(115)
	Input.action_release("fire")
	check(light.shots_fired==6,"Bofors continues steady automatic fire without clips or reserve limit")
	check(light.projectile_speed==850 and light.weapon.reload_seconds==.5,"Bofors 850m/s and two-shot-per-second cycle")
	game.malta_mission.interaction.leave_gun()
	var before: int=battery.effects.emitted.air
	battery._light_impact(Vector3(1000,500,1000),null,CombatTeams.PLAYER)
	check(before==battery.effects.emitted.air,"Bofors miss does not produce timed flak explosion")
	check(battery.damage_at_distance(0)==150 and battery.damage_at_distance(3)==100 and battery.damage_at_distance(8)==50 and battery.damage_at_distance(15)==0,"Heavy blast uses configurable smooth distance bands")
	for id in ["fuselage","left_wing","engine","fuel_tank","cockpit"]:
		var foe := EnemyAircraft.new()
		game.add_child(foe)
		foe.freeze=true
		foe.reset_pending=false
		foe.global_position=Vector3(1000,800,1000)
		await frames(3)
		# Isolate one REAL component sensor to verify primary damage without overlap.
		var chosen: AircraftHitbox
		for box in foe.components.hitboxes:
			if String(box.definition.id)==id:chosen=box
			else:box.collision_layer=0
		foe.collision_layer=0
		await frames(2)
		var shape: CollisionShape3D = chosen.get_child(0)
		var centre: Vector3 = shape.global_position
		battery.light_projectiles.spawn(centre+Vector3.UP*20,Vector3.DOWN*850,1,0,light.get_rid(),true,CombatTeams.PLAYER)
		await frames(5)
		var expected: float = float(light.weapon.location_damage[id])
		check(is_equal_approx(100-foe.health.hp,expected),"Swept Bofors "+id+" hit applies exact primary HP "+str(expected))
		check(foe.components.last_hit==StringName(id),"Actual component critical framework receives "+id)
		foe.queue_free()
		await frames(2)
	var slot: int=battery.light_projectiles.free.back()
	battery.light_projectiles.spawn(Vector3(0,2000,0),Vector3(100,0,0),1,1,light.get_rid(),true,CombatTeams.PLAYER)
	await frames(30)
	check(battery.light_projectiles.velocities[slot].y< -2 and battery.light_projectiles.positions[slot].y<2000,"AA shell drops under gravity while travelling")
	game.restart_malta()
	await frames(20)
	check(game.field.aa_battery.guns.size()==18 and get_nodes_in_group("friendly_aa").size()==21,"Retry replaces the three airfield installations plus the fort guns without duplicates")
	check(game.field.aa_battery.guns.all(func(g):return g.hp==150 and g.cooldown==0),"Retry restores health and ammunition independently")
	print("LAYERED AA RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)
