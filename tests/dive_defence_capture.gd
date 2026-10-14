extends SceneTree
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in range(n):await process_frame
func capture(name: String) -> void:
	await frames(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/"+name+".png")
func run() -> void:
	var session: Node3D=load("res://main.tscn").instantiate()
	root.add_child(session)
	await frames(10)
	session.show_missions()
	session.missions_menu.mission_picker.select(1)
	session.missions_menu._choose_mission(1)
	await capture("dive-defence-menu")
	session.start_aa_defence()
	await frames(15)
	await capture("dive-defence-on-foot")
	var controls: AirfieldInteraction=session.malta_mission.interaction
	controls.mount_gun(controls.nearest())
	await frames(4)
	session.aa_defence.clock=.01
	await frames(14)
	var gun: BritishAAGun=controls.occupied_gun
	var foe: EnemyAircraft=session.aa_defence.alive[0]
	var direction: Vector3=gun.global_basis.inverse()*(foe.global_position-gun.global_position)
	gun.yaw.rotation.y=atan2(-direction.x,-direction.z)
	gun.elevation.rotation.x=atan2(direction.y,Vector2(direction.x,direction.z).length())
	await capture("dive-defence-mounted")
	quit()
