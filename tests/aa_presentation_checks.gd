extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if value: passed+=1;print("PASS: ",message)
	else: failed+=1;push_error("FAIL: "+message)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await frames(8)
	scene.start_malta("ta_qali","spitfire","encounter")
	await frames(20)
	var mission: MaltaMission = scene.malta_mission
	check(mission.board_nearest() and mission.leave_aircraft(),"Board/exit creates the actual hidden flight HUD")
	var gun: BritishAAGun = mission.world.aa_battery.guns[0]
	mission.pilot.global_position = gun.global_position + mission.world.fields.ta_qali.global_basis.x*5 + Vector3.UP*1.05
	await frames(4)
	check(mission.interaction.mount_gun(gun),"Mount AA with flight HUD hidden")
	var enemy: EnemyAircraft = scene.enemy
	enemy.freeze = true
	enemy.reset_pending = false
	enemy.global_position = gun.camera.global_position - gun.camera.global_basis.z*500
	await frames(4)
	var widget: VBoxContainer = scene.encounters.enemy_widgets[enemy.get_instance_id()]
	check(widget.visible and enemy.marker_name in widget.get_child(0).text,"Focused enemy name tag visible through gunner camera")
	check(widget.get_child(1).visible,"Nearby enemy health displayed above visible aircraft")
	check("500 m" in widget.get_child(0).text,"Tag distance measured from AA camera")
	enemy.global_position = gun.camera.global_position + gun.camera.global_basis.z*500
	await frames(4)
	check(widget.visible and not widget.get_child(1).visible and widget.position.x > root.size.x*.6,"Enemy behind camera retains edge name cue without overhead HP")
	var sound: AudioStreamOggVorbis = gun.sound.stream
	check(sound.resource_path.ends_with("aa_cannon_shot.ogg") and not sound.loop,"Dedicated cannon recording replaces machine-gun stream without looping")
	check(sound.get_length()>.4 and sound.get_length()<.49 and is_equal_approx(gun.rounds_per_second,2),"Distinct reports fit two-shot-per-second cadence")
	var before: int = gun.shots_fired
	Input.action_press("fire")
	await frames(240)
	Input.action_release("fire")
	check(gun.shots_fired-before >= 4 and gun.shots_fired-before <= 5,"Holding Ctrl fires approximately twice per second")
	var effect: FlakEffectPool = mission.world.aa_battery.effects
	var slot := effect.cursor
	var point := gun.global_position + Vector3.UP*100
	mission.world.aa_battery._burst(point,null,CombatTeams.PLAYER)
	check(effect.particles[slot].global_position.is_equal_approx(point) and effect.particles[slot].scale.x>5,"Large shell flash appears at actual burst position")
	check(effect.particles[(slot+3)%FlakEffectPool.CAPACITY].scale.x>=3.5,"Expanded dark smoke accompanies large burst")
	check(mission.world.aa_battery.aerial_burst_visual_scale==4,"Large visual burst scale remains independently configurable")
	check(effect.particles.size()==192,"Larger bursts retain bounded effect pool")
	mission.interaction.leave_gun()
	check(not gun.mounted and not gun.sound.playing,"Exit still immediately stops firing and sound")
	print("AA PRESENTATION RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)
