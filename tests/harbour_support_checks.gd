extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print("PASS: " if ok else "FAIL: ", label)
func run() -> void:
	GameAudioMixer.instance.playback_enabled = false
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_harbour()
	await frames(180)
	var mission: HarbourInterception = game.harbour
	mission.phase = "SPAWNING"
	mission._spawn_wave()
	await frames(3)
	var baseline := EnemyPilot.new()
	var cr42 := EnemyAircraftDefinition.find("cr42")
	check(mission.escorts.all(func(a): return is_equal_approx(a.ai.aim_error_degrees, baseline.aim_error_degrees*4) and is_equal_approx(a.guns.spread_degrees,cr42.dispersion*1.6)), "Normal harbour escorts have increased aim error and dispersion")
	check(mission.escorts.all(func(a): return a.ai.burst_duration==.5 and a.ai.burst_rest==2 and a.ai.grace_period==3), "Normal pilots fire shorter bursts with longer pauses and initial reaction time")
	check(mission.bomber.rear_gunner.skill_level==0 and mission.bomber.additional_gunners.all(func(g):return g.skill_level==0), "Normal bomber gunners use human Cadet tracking without changed bullet damage")
	game.restart_malta(); await frames(180)
	mission=game.harbour;mission.wave=2;mission.phase="SPAWNING";mission._spawn_wave();await frames(3)
	check(mission.escorts.size()==2 and mission.escorts.all(func(a): return a.encounter_ace and is_equal_approx(a.ai.aim_error_degrees,baseline.aim_error_degrees*.2) and is_equal_approx(a.guns.spread_degrees,cr42.dispersion*.25)), "Both final-wave aces retain their exact previous accuracy")
	check(mission.escorts.all(func(a): return a.ai.burst_duration==baseline.burst_duration and a.ai.burst_rest==baseline.burst_rest and a.ai.pursuit_prediction_seconds==5 and a.ai.grace_period==0), "Ace burst, reaction and pursuit settings remain unchanged")
	baseline.free()
	game.show_selection(false);game.start_malta("luqa","spitfire");await frames(180)
	var battery: AirfieldAABattery=game.field.aa_battery
	var gun: BritishAAGun=battery.guns.filter(func(g):return not g.weapon.heavy)[0]
	var heavy: BritishAAGun=battery.guns.filter(func(g):return g.weapon.heavy)[0]
	var saved_mode:=AAMouseControls.fire_control_mode
	game.malta_mission.bofors_mode_option.select(1)
	game.malta_mission.bofors_mode_option.item_selected.emit(1)
	check(AAMouseControls.fire_control_mode==1,"Pause settings selects optional Bofors predictor mode")
	var cfg:=ConfigFile.new();cfg.load("user://aa_controls.cfg")
	check(cfg.get_value("aa","bofors_assist",false),"Assist preference persists beside existing mouse sensitivity")
	gun.start_operation();gun.yaw.rotation.y=0;gun.elevation.rotation.x=deg_to_rad(25);gun.mouse_controls.reset_target()
	var foe:=EnemyAircraft.new();game.add_child(foe);await frames(3)
	foe.freeze=true;foe.reset_pending=false;foe.ai.set_physics_process(false)
	foe.global_position=gun.muzzle.global_position-gun.muzzle.global_basis.z*500+gun.muzzle.global_basis.x*20
	foe.linear_velocity=Vector3.ZERO;await frames(3)
	gun.mouse_controls.reset_target();var before:=gun.mouse_controls.target_yaw
	gun.aim_assist.scan_clock=0;gun.aim_assist.update(.1)
	check(gun.aim_assist.target==null and gun.mouse_controls.target_yaw==before,"Unassigned hostile does not receive automatic aiming assistance")
	check(gun.predictor_post!=null and not gun.predictor_post.is_destroyed,"Existing Bofors connects to its local predictor")
	check(gun.shots_fired==0,"Assistance never initiates firing")
	Input.action_press("fire");await frames(100);Input.action_release("fire")
	check(gun.shots_fired==2,"Assisted Bofors still requires held player fire and keeps two rounds per second")
	gun.cooldown=0;gun.aim_error_degrees=0
	var pool: ProjectilePool=battery.pool_for(gun.weapon)
	var slot: int=pool.free.back()
	check(gun.fire_round() and pool.positions[slot].distance_to(gun.muzzle.global_position)<.01 and pool.velocities[slot].normalized().dot(-gun.muzzle.global_basis.z)>.999,"Assisted shots remain physical shells along the actual muzzle direction")
	AAMouseControls.set_bofors_assist(false);before=gun.mouse_controls.target_yaw;gun.aim_assist.update(.1)
	check(gun.mouse_controls.target_yaw==before and gun.aim_assist.target==null,"Disabled assistance leaves manual aim untouched")
	AAMouseControls.set_bofors_assist(true)
	foe.team_id=CombatTeams.PLAYER;gun.aim_assist.scan_clock=0;gun.aim_assist.update(.1)
	check(gun.aim_assist.target==null,"Friendly aircraft cannot be assisted targets")
	foe.team_id=CombatTeams.ENEMY
	var block:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(35,35,35);shape.shape=box;block.add_child(shape);game.add_child(block);block.global_position=gun.muzzle.global_position.lerp(foe.global_position,.5)
	await frames(3);gun.aim_assist.scan_clock=0;gun.aim_assist.update(.1)
	check(gun.aim_assist.target==null,"Terrain/building obstruction blocks assist acquisition")
	block.queue_free();await frames(3)
	foe.global_position=gun.muzzle.global_position+gun.muzzle.global_basis.x*500;gun.aim_assist.scan_clock=0;gun.aim_assist.update(.1)
	check(gun.aim_assist.target==null,"Assist does not acquire enemies far outside the player's sight")
	gun.stop_operation();gun.aim_assist.update(.1)
	var shots:=gun.shots_fired
	await frames(100)
	check(gun.aim_assist.target==null and gun.shots_fired==shots,"An empty Bofors remains idle")
	heavy.start_operation();before=heavy.mouse_controls.target_yaw;heavy.aim_assist.update(.1)
	check(heavy.aim_assist.target==null and heavy.mouse_controls.target_yaw==before and heavy.weapon.reload_seconds==5,"Heavy gun remains fully manual with its five-second reload")
	heavy.stop_operation();foe.queue_free()
	AAMouseControls.set_fire_control_mode(saved_mode)
	# A real fueled enemy's ground-impact presentation, then enemy cleanup.
	var wreck:=EnemyAircraft.new();game.add_child(wreck);await frames(3)
	wreck.freeze=true;wreck.reset_pending=false;wreck.ai.set_physics_process(false)
	wreck.global_position=game.field.fields.luqa.to_global(Vector3(-110,1.3,40))
	wreck.take_damage(1000);wreck._finish_impact(wreck.global_position)
	await frames(140)
	var fires:=get_nodes_in_group("land_wreck_fires")
	check(fires.size()==1,"Fueled enemy land wreck creates one lingering fire")
	var fire: WreckFire=fires[0] if not fires.is_empty() else null
	check(fire!=null and fire.smoke.emitting and fire.flames.emitting and fire.get_parent()==AircraftImpactService.instance,"Fire and dark smoke are world-owned rather than attached to disappearing aircraft")
	wreck.queue_free();await frames(3)
	check(is_instance_valid(fire) and fire.smoke.emitting,"Fire survives enemy aircraft removal")
	check(fire!=null and fire.remains.visible and fire.remains.get_child_count()>0 and fire.remains.get_child_count()<=16,"Bounded real wreck geometry remains among the flames after enemy cleanup")
	if is_instance_valid(fire):
		fire.age=fire.duration-4;await frames(2)
		check(not fire.flames.emitting and not fire.smoke.emitting,"Wreck fire stops emitting before its bounded expiry")
	game.restart_malta();await frames(12)
	check(get_nodes_in_group("land_wreck_fires").is_empty(),"Retry removes old wreck fires and smoke")
	game.queue_free();await frames(10)
	print("HARBOUR SUPPORT RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)
