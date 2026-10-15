class_name BritishAAGun
extends StaticBody3D
## Manual-only British AA. Empty positions never select targets or aim/fire.
signal destroyed
@export var weapon: AAWeaponDefinition
var command_station: Node3D
var mouse_controls: AAMouseControls
var trigger_held: bool = false
var fuze_seconds: float = 1.14
var breech: MeshInstance3D
@export var max_hp: float = 150
var range_metres: float = 2400
var projectile_speed: float = 700
var rounds_per_second: float = 2.0
var maximum_lifetime: float = 4
var direct_damage: float = 180
var aim_error_degrees: float = 0.35
var traverse_degrees: float = 45
var elevation_degrees: float = 30
@export var minimum_elevation_degrees: float = 5
@export var maximum_elevation_degrees: float = 85
var fuse_distance: float = 900
var hp: float = 150
var is_destroyed: bool = false
var mounted: bool = false
var operator_session: AirfieldInteraction
var battery: AirfieldAABattery
var yaw: Node3D
var elevation: Node3D
var muzzle: Node3D
var elevation_origin: Vector3
var sound: AudioStreamPlayer3D
var flash: MeshInstance3D
var camera: Camera3D
var cooldown: float = 0
var recoil: float = 0
var shots_fired: int = 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	if weapon == null: weapon = load("res://weapon_definitions/heavy_aa.tres")
	projectile_speed = weapon.velocity
	rounds_per_second = 1 / maxf(weapon.reload_seconds,.001)
	traverse_degrees = weapon.traverse
	elevation_degrees = weapon.elevation
	direct_damage = weapon.direct_damage
	maximum_lifetime = weapon.maximum_lifetime
	aim_error_degrees = weapon.dispersion_degrees
	fuze_seconds = weapon.fuze_seconds
	add_to_group("friendly_aa")
	rng.randomize()
	hp = max_hp
	collision_layer = 1
	collision_mask = 0
	var asset: PackedScene = load("res://assets/ground/british_aa/British_AA_Emplacement.glb")
	var model := asset.instantiate()
	add_child(model)
	_cull_visuals(model)
	yaw = model.find_child("YawPivot", true, false)
	elevation = model.find_child("ElevationPivot", true, false)
	muzzle = model.find_child("Muzzle", true, false)
	elevation_origin = elevation.position
	if weapon.heavy:
		# Original heavier cradle/barrel silhouette around the imported emplacement.
		var steel := MeshKit.material(Color("424a3c"))
		MeshKit.box(elevation,Vector3(.8,.65,1.8),Vector3(0,0,.4),steel)
		MeshKit.rod(elevation,Vector3(0,0,0),Vector3(0,0,-4),.15,steel)
		muzzle.position = Vector3(0,0,-4)
		breech = MeshKit.box(elevation,Vector3(.55,.3,.5),Vector3(0,.4,1),steel)
	var label := Label3D.new()
	label.name = "FriendlyAALabel"
	label.text = weapon.display_name + " · MANUAL"
	label.position = Vector3(0, 4, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("acd7ac")
	label.font_size = 30
	label.pixel_size = 0.03
	label.visibility_range_end = 500
	add_child(label)
	for spec in [Vector3(6.8,0.8,0.6),Vector3(1.9,2.0,1.9)]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec
		shape.shape = box
		shape.position = Vector3(0,0.4,2.8) if spec.x > 3 else Vector3(0,1,0)
		add_child(shape)
	flash = MeshKit.sphere(muzzle, Vector3.ONE * (.8 if weapon.heavy else .35), Vector3.ZERO, MeshKit.material(Color("ffdf98")))
	flash.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.visible = false
	camera = Camera3D.new()
	camera.name = "GunnerCamera"
	camera.fov = 58
	camera.far = 100000
	# Sight ahead of the barrel tip: gun geometry cannot obstruct this view.
	camera.position = Vector3(0,0.22,-1.0)
	muzzle.add_child(camera)
	sound = AudioStreamPlayer3D.new()
	sound.stream = load(weapon.sound_path)
	sound.bus = "Guns"
	sound.volume_db = weapon.sound_volume_db
	sound.pitch_scale = 1.0
	sound.unit_size = 25
	sound.max_distance = 2000
	sound.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	muzzle.add_child(sound)
	mouse_controls = AAMouseControls.new()
	mouse_controls.gun = self
	add_child(mouse_controls)

func get_team_id() -> int:
	return CombatTeams.PLAYER

func take_damage(amount: float) -> void:
	if is_destroyed or amount <= 0 or not is_finite(amount): return
	hp = clampf(hp - amount, 0, max_hp)
	if hp == 0:
		is_destroyed = true
		stop_operation()
		battery.effects.puff(global_position + Vector3.UP, "air", 2)
		destroyed.emit()

func start_operation(operator: AirfieldInteraction = null) -> void:
	if is_destroyed: return
	mounted = true
	operator_session = operator
	camera.make_current()
	mouse_controls.begin()

func stop_operation() -> void:
	if mounted:mouse_controls.finish()
	mounted = false
	trigger_held = false
	operator_session = null
	sound.stop()
	flash.visible = false
	recoil = 0
	elevation.position = elevation_origin

func _physics_process(delta: float) -> void:
	cooldown = maxf(0,cooldown-delta)
	recoil = maxf(0, recoil - delta * 0.7)
	elevation.position = elevation_origin + Vector3(0,0,recoil)
	flash.visible = (mounted or (is_instance_valid(command_station) and command_station.command_active())) and recoil > weapon.recoil_metres * .7
	if breech != null:breech.position.z = 1 + .3 * sin(clampf(cooldown / maxf(weapon.reload_seconds,.001),0,1)*PI)
	if not mounted and is_instance_valid(command_station):
		command_station.drive_gun(self,delta)
		return
	if not mounted or is_destroyed: return
	if operator_session != null and operator_session.mission_ended():
		stop_operation()
		return
	if mouse_controls.blocked():
		trigger_held = true
		return
	if weapon.heavy:
		fuze_seconds = clampf(fuze_seconds + Input.get_axis("throttle_down", "throttle_up") * weapon.fuze_adjustment_per_second * delta,weapon.minimum_fuze_seconds,maximum_lifetime)
		fuse_distance = fuze_seconds * projectile_speed
	var pressed := mouse_controls.sample(delta)
	if pressed and (not weapon.heavy or not trigger_held):fire_round()
	trigger_held = pressed

func fire_round(command_order: bool = false) -> bool:
	if is_destroyed or cooldown > 0:return false
	if command_order:
		if not is_instance_valid(command_station) or not command_station.command_active() or not command_station.orders.has(self):return false
	elif not mounted or mouse_controls.blocked():return false
	var forward: Vector3 = -muzzle.global_basis.z
	var spread := deg_to_rad(aim_error_degrees)
	var direction := (forward + muzzle.global_basis.x * rng.randfn(0,spread) + muzzle.global_basis.y * rng.randfn(0,spread)).normalized()
	# Friendly bodies block shots; terrain/buildings receive normal swept impacts.
	var query := PhysicsRayQueryParameters3D.create(muzzle.global_position,muzzle.global_position + direction * fuse_distance,15,[get_rid()])
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_method("get_team_id") and hit.collider.get_team_id() == CombatTeams.PLAYER: return false
	if not battery.pool_for(weapon).spawn(muzzle.global_position, direction * projectile_speed, fuze_seconds if weapon.heavy else maximum_lifetime, direct_damage, get_rid(), true, CombatTeams.PLAYER): return false
	shots_fired += 1
	cooldown = weapon.reload_seconds
	recoil = weapon.recoil_metres
	battery.effects.puff(muzzle.global_position, "muzzle", .8 if weapon.heavy else .25)
	var voices := 0
	for gun in get_tree().get_nodes_in_group("friendly_aa"):
		if gun.sound.playing:voices += 1
	if GameAudioMixer.instance.playback_enabled and voices < weapon.simultaneous_reports:
		sound.pitch_scale = rng.randf_range(0.97,1.03)
		sound.play()
	return true

func _cull_visuals(node: Node) -> void:
	if node is MeshInstance3D:
		node.visibility_range_end = 3500
		node.visibility_range_end_margin = 250
	for child in node.get_children(): _cull_visuals(child)

func status_text() -> String:
	return "%s · HP %d/%d · AMMO ∞ · %s\n%s" % [weapon.display_name,hp,max_hp,("AUTO RELOAD %.1fs"%cooldown) if cooldown > 0 else "READY",("FUZE %.2fs · W/S adjust · LMB single shot"%fuze_seconds) if weapon.heavy else "HOLD LMB · 2 shots/sec"]
