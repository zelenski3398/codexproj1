extends SceneTree
## Real input, collision, boarding and reusable skinned character integration.
var session: Node3D
var checks: int = 0
var failures: int = 0
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	session = preload("res://main.tscn").instantiate()
	root.add_child(session)
	await _frames(3)
	for kind in ["spitfire", "sea_gladiator"]:
		session.start_malta("ta_qali", kind)
		await _frames(180)
		var mission: MaltaMission = session.malta_mission
		var pilot: GroundPilot = mission.pilot
		var avatar: RafPilotAvatar = pilot.avatar
		_check(avatar.skeleton.get_bone_count() == 18 and avatar.animator.get_animation_list().size() >= 3, kind+": imported 18-bone skin and three animations")
		_check(avatar.pose == "Idle" and pilot.is_on_floor(), kind+": live pilot idles on collision-driven terrain")
		var shape: CapsuleShape3D = pilot.get_child(0).shape
		_check(is_equal_approx(shape.radius, 0.35) and is_equal_approx(shape.height, 1.8) and pilot.collision_layer == 16 and pilot.collision_mask == 7, "Existing capsule and collision masks unchanged")
		var start: Vector3 = pilot.global_position
		Input.action_press("throttle_down")
		await _frames(30)
		_check(pilot.global_position.distance_to(start) > 0.4 and avatar.pose == "Walk" and avatar.animator.is_playing(), kind+": normal S input walks and animates the new rig")
		Input.action_release("throttle_down")
		Input.action_press("throttle_up")
		await _frames(30)
		Input.action_release("throttle_up")
		await _frames(5)
		_check(avatar.pose == "Idle" and absf(avatar.rotation.y - pilot.yaw) < 0.001, "Stopping returns to idle and model follows the existing yaw")
		_check(mission.board_nearest(), kind+": unchanged nearby boarding succeeds")
		await _frames(30)
		var aircraft: FlightAircraft = mission.occupied
		var seated: RafPilotAvatar = aircraft.seated_pilot
		_check(not pilot.active and not pilot.visible and pilot.collision_layer == 16 and seated.visible and seated.pose == "Seated", "Boarding hides walking geometry while retaining a damageable seat capsule and one visible pilot")
		var points: Dictionary = {}
		for index in range(seated.skeleton.get_bone_count()):
			var name: String = seated.skeleton.get_bone_name(index)
			points[name] = aircraft.to_local(seated.skeleton.to_global(seated.skeleton.get_bone_global_pose(index).origin))
		print(kind, " SEATED JOINTS=", points)
		var knee_ok: bool = true
		var wrist_ok: bool = true
		for name in points:
			if name.begins_with("Shin"):
				knee_ok = knee_ok and absf(points[name].x)<0.30 and points[name].y<0.25
			if name.begins_with("Hand"):
				wrist_ok = wrist_ok and points[name].y>0.15 and points[name].y<0.65
		_check(knee_ok and wrist_ok, kind+": knees bend inside cockpit and wrists reach forward control height")
		seated.set_first_person_hidden(true)
		_check(not seated.character.visible and aircraft.input_enabled, "First-person hiding hook leaves controls and skeleton intact")
		seated.set_first_person_hidden(false)
		var hp: float = aircraft.health.hp
		_check(mission.leave_aircraft(), kind+": normal stopped-engine exit succeeds")
		await _frames(5)
		_check(pilot.active and pilot.visible and not seated.visible and aircraft.health.hp == hp and pilot.camera.current, "Exit restores walking camera/character without changing aircraft health")
		session.show_selection()
		await _frames(3)
	session.queue_free()
	await _frames(3)
	print("PILOT CHARACTER RESULT: ",checks-failures,"/",checks," passed")
	quit(1 if failures else 0)
func _frames(count: int) -> void:
	for frame in range(count):await physics_frame
func _check(ok: bool, message: String) -> void:
	checks+=1
	if ok:print("PASS: ",message)
	else:failures+=1;push_error("FAIL: "+message)
