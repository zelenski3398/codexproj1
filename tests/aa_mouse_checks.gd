extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in range(n):await physics_frame
func check(ok: bool,label: String) -> void:
	if ok:passed+=1;print("PASS: ",label)
	else:failed+=1;push_error("FAIL: "+label)
func move_mouse(delta: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = delta
	event.screen_relative = delta
	Input.parse_input_event(event)
func run() -> void:
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	game.start_aa_defence()
	await frames(20)
	var mission: DiveDefenceMission=game.aa_defence
	mission.definition=mission.definition.duplicate()
	mission.definition.gun_blast_damage=0
	mission.definition.player_blast_damage=0
	var interaction: AirfieldInteraction=game.malta_mission.interaction
	for index in [0,4]:
		var gun: BritishAAGun=mission.guns[index]
		game.malta_mission.pilot.global_position=interaction.find_exit(gun,5)
		await frames(2)
		check(interaction.mount_gun(gun),"Mount "+gun.weapon.display_name)
		await frames(2)
		check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Mouse captured on actual desktop mount")
		var yaw: float=gun.yaw.rotation.y
		var pitch: float=gun.elevation.rotation.x
		move_mouse(Vector2(80,-40))
		await frames(45)
		check(gun.yaw.rotation.y<yaw-.1 and gun.elevation.rotation.x>pitch+.05,"Relative mouse X/Y moves actual traverse/elevation without arrows")
		Input.action_press("aa_zoom")
		await frames(60)
		check(gun.camera.fov<32 and (-gun.camera.global_basis.z).dot(-gun.muzzle.global_basis.z)>.999,"RMB sight zoom preserves barrel/camera orientation")
		Input.action_release("aa_zoom")
		await frames(60)
		check(gun.camera.fov>57,"Releasing RMB restores ordinary sight")
		gun.aim_error_degrees=0
		Input.action_press("aa_fire")
		await frames(650 if gun.weapon.heavy else 250)
		Input.action_release("aa_fire")
		check(gun.shots_fired==(1 if gun.weapon.heavy else 5),"LMB heavy single-shot / uninterrupted 2 Hz Bofors with infinite ammunition")
		var pool: ProjectilePool=gun.battery.pool_for(gun.weapon)
		var slot: int=pool.free.back()
		gun.cooldown=0
		check(gun.fire_round(),"Loaded gun fires from actual muzzle")
		check(pool.positions[slot].distance_to(gun.muzzle.global_position)<.01 and pool.velocities[slot].normalized().dot(-gun.muzzle.global_basis.z)>.999,"Projectile starts at muzzle and follows actual barrel, not aim target")
		paused=true
		await process_frame
		await process_frame
		check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Pause releases mouse capture")
		paused=false
		await process_frame
		var click:=InputEventMouseButton.new()
		click.button_index=MOUSE_BUTTON_LEFT
		click.pressed=true
		Input.parse_input_event(click)
		await frames(2)
		check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"User click recaptures after pause")
		click=InputEventMouseButton.new()
		click.button_index=MOUSE_BUTTON_LEFT
		Input.parse_input_event(click)
		await frames(2)
		game.malta_mission.chart_panel.show()
		await process_frame
		await process_frame
		check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Navigation menu releases capture")
		game.malta_mission.chart_panel.hide()
		check(interaction.leave_gun() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Dismount restores cursor and walking")
	# Track the same force-driven Stuka approach, dive and withdrawal twice,
	# generating only mouse events from measured angular error (test driver).
	for index in [0,4]:
		game.restart_malta()
		await frames(20)
		mission=game.aa_defence
		mission.definition=mission.definition.duplicate()
		mission.definition.gun_blast_damage=0
		mission.definition.player_blast_damage=0
		interaction=game.malta_mission.interaction
		var gun: BritishAAGun=mission.guns[index]
		game.malta_mission.pilot.global_position=interaction.find_exit(gun,5)
		await frames(2)
		interaction.mount_gun(gun)
		await frames(2)
		mission.clock=.01
		await frames(10)
		var foe: EnemyAircraft=mission.alive[0]
		var errors: Dictionary={"APPROACH":[],"DIVE":[],"PULL OUT":[]}
		var rate_ok:=true
		for tick in range(10500):
			if foe.is_destroyed:break
			var offset: Vector3=gun.global_basis.inverse()*(foe.global_position-gun.global_position)
			var wanted_yaw: float=atan2(-offset.x,-offset.z)
			var wanted_pitch: float=atan2(offset.y,Vector2(offset.x,offset.z).length())
			var yerror: float=wrapf(wanted_yaw-gun.yaw.rotation.y,-PI,PI)
			var perror: float=wanted_pitch-gun.elevation.rotation.x
			var scale: float=deg_to_rad(gun.weapon.mouse_degrees_per_pixel)*AAMouseControls.sensitivity
			move_mouse(Vector2(-yerror,-perror)*.35/scale)
			var before: Vector2=Vector2(gun.yaw.rotation.y,gun.elevation.rotation.x)
			await physics_frame
			if absf(wrapf(gun.yaw.rotation.y-before.x,-PI,PI))>deg_to_rad(gun.traverse_degrees)/120+.001:rate_ok=false
			var state: String=foe.ai.attack_state
			if errors.has(state) and tick>120 and wanted_pitch>deg_to_rad(7) and wanted_pitch<deg_to_rad(83):errors[state].append(rad_to_deg(Vector2(yerror,perror).length()))
			if state=="CIRCLE" and errors["PULL OUT"].size()>50:break
		for phase in errors:
			var samples: Array=errors[phase]
			var average:=0.0
			for value in samples:average+=value/maxi(samples.size(),1)
			check(samples.size()>30 and average<8,gun.weapon.display_name+" tracks real Stuka "+phase+" using mouse only; mean error %.2f° / %d samples"%[average,samples.size()])
		check(rate_ok,"Smooth tracking obeys configured traverse limit")
	game.queue_free()
	await frames(5)
	print("AA MOUSE RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)
