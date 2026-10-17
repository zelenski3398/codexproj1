extends SceneTree
var passed: int = 0
var failed: int = 0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, label: String) -> void:
	if ok: passed+=1
	else: failed+=1
	print("PASS: " if ok else "FAIL: ",label)
func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.start_flight("spitfire")
	var enemy: EnemyAircraft = world.enemy
	enemy.request_reset()
	enemy.pending_reset_pose = Transform3D(Basis.IDENTITY,Vector3(0,600,500))
	enemy.pending_reset_velocity = Vector3(0,0,-65)
	await frames(5)
	enemy.components.apply_damage(&"engine",1000,Vector3.ZERO,false,"mechanical")
	var start: Vector3 = enemy.global_position
	var previous_roll: float = enemy.pilot.roll
	var maximum_step: float = 0
	var firing: bool = false
	for i in 240:
		await physics_frame
		maximum_step = maxf(maximum_step,absf(enemy.pilot.roll-previous_roll))
		previous_roll = enemy.pilot.roll
		firing = firing or enemy.pilot.fire
	check(enemy.ai.tactic=="ENGINE-OUT GLIDE" and not firing and not enemy.is_destroyed,"Engine-out enemy abandons attacks and selects glide response")
	check(maximum_step <= enemy.ai.command_slew_rate/120.0+0.001 and enemy.global_position.distance_to(start)>60,"Emergency AI uses bounded existing pilot commands and continuous physical motion")
	check(enemy.components.power_factor()==0 and enemy.components.integrity_ratio(&"engine")==0,"AI cannot repair engine or restore lost thrust")
	for controller in [BomberPilot.new(),EscortPilot.new(),DiveAttackPilot.new(),HarbourCombatPilot.new()]:
		enemy.ai.set_physics_process(false)
		controller.aircraft = enemy
		controller.target = world.aircraft
		enemy.add_child(controller)
		controller.set_physics_process(false)
		controller._physics_process(0.01)
		check(controller.tactic=="ENGINE-OUT GLIDE" and not enemy.pilot.fire,"Damage override works for "+controller.get_class()+" "+controller.get_script().resource_path)
		controller.queue_free()
	# Response stops after an explicit live-aircraft repair; no repair by AI.
	enemy.components.reset()
	enemy.health.reset()
	enemy.ai.damage_decision_clock=0
	enemy.ai.set_physics_process(true)
	await frames(3)
	check(enemy.ai.damage_emergency.is_empty(),"Explicit repair clears stale emergency decisions")
	world.queue_free()
	await frames(10)
	print("FAILURE AI RESULT: ",passed,"/",passed+failed," passed")
	quit(1 if failed else 0)
