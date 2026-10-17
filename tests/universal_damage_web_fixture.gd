extends Node3D
## Isolated release fixture. Never a production entry scene or runtime API.
var checks: int = 0
var failed: int = 0
var messages: PackedStringArray = []
func _ready() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failed += 1
	messages.append(("PASS: " if value else "FAIL: ")+label)
	print(messages[-1])
func run() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(-15,105,-15)
	camera.look_at(Vector3(0,100,0))
	for kind in ["spitfire","sea_gladiator","stuka","cr42","c200","c202","sm79"]:
		var plane: FlightAircraft
		if kind == "spitfire": plane = FlightAircraft.new()
		elif kind == "sea_gladiator": plane = SeaGladiator.new()
		elif kind == "stuka": plane = EnemyAircraft.new()
		else:
			plane = ItalianEnemy.new()
			plane.definition = EnemyAircraftDefinition.find(kind)
		plane.reset_position = Vector3(0,100,0)
		add_child(plane)
		plane.request_reset()
		await frames(4)
		plane.freeze = true
		if plane is EnemyAircraft:
			plane.ai.set_physics_process(false)
			plane.rear_gunner.set_physics_process(false)
		plane.components.apply_damage(&"engine",1000,Vector3.ZERO,false,"mechanical")
		check(plane.components.engine_power(&"engine")==0 and not plane.is_destroyed and plane.impact_effects.explosion_count==0,kind+" engine fails without explosive hull loss")
		if kind == "sm79": check(is_equal_approx(plane.components.power_factor(),2.0/3.0),"SM79 retains independent two-engine power in release WebGL")
		plane.components.detach(&"left_wing")
		await frames(4)
		check(plane.impact_effects.component_debris_count==1 and plane.components.wing_efficiency(&"left_wing")==0,kind+" actual geometry detaches and loses lift in release WebGL")
		plane.impact_effects.reset()
		plane.components.reset()
		plane.health.reset()
		check(plane.model.visible and plane.impact_effects.original_meshes.is_empty(),kind+" restores geometry in release WebGL")
		plane.queue_free()
		await frames(4)
	var service := AircraftImpactService.obtain()
	service.clear_all()
	await frames(4)
	var result := {"done":true,"checks":checks,"failed":failed,"messages":messages}
	print("UNIVERSAL WEB FIXTURE: ",checks-failed,"/",checks," passed")
	if OS.has_feature("web"): JavaScriptBridge.eval("window.universalDamageFixture="+JSON.stringify(result),true)
